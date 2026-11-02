param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$t=$null;$e=$null;$source=Join-Path $RepositoryRoot AIPyTeam.ps1
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$t,[ref]$e)
foreach($f in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){if($f.Extent.Text -match '^function\s'){. ([scriptblock]::Create($f.Extent.Text))}}
$class=$ast.FindAll({param($n)$n -is [Management.Automation.Language.TypeDefinitionAst]},$true)|Where-Object Name -eq ProjectTeam
. ([scriptblock]::Create($class.Extent.Text))
$rows=New-Object Collections.Generic.List[object]
function Assert($ok,$message){if(-not $ok){throw $message}}
function Case($name,[scriptblock]$body){try{& $body;$rows.Add(@{name=$name;pass=$true})}catch{$rows.Add(@{name=$name;pass=$false;error=$_.Exception.Message})}}
$script:GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot;LastpydevCode='x = 1';GlobalResponse=@();GlobalpydevResponse=@();FileVersion=2;RAG=$false;UserInput='synthetic';Stream=$false;VerbosePrompt=$false}
$script:MaxTokens=256;$script:DeploymentChat='opaque-alias'
$reviewer=[ProjectTeam]::new('Analyst','Analyst','synthetic',0,1,$GlobalState)
$developer=[ProjectTeam]::new('Developer','Developer','synthetic',0,1,$GlobalState)
# Only transport is substituted; real class methods, dispatcher and Responses adapter execute.
$script:GlobalState|Add-Member AzureOpenAIProtocol Responses
$script:GlobalState|Add-Member AzureResponsesTimeoutSec 60
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-key'
$script:calls=0
function Invoke-RestMethod {param($Uri,$Method,$Headers,$Body,$TimeoutSec,$ErrorAction,$ContentType) $script:calls++;throw 'synthetic secret-like error MUST_NOT_PERSIST'}
function Invoke-WebRequest {throw 'Unexpected transport'}
Case 'parser' {Assert ($e.Count -eq 0) 'Parser errors'}
Case 'feedback-caller-propagates' {$before=$calls;$caught=$false;try{Set-FeedbackAndGenerateResponse $reviewer $developer -GlobalState $GlobalState}catch{$caught=$true};Assert ($caught -and $calls -eq ($before+1)) 'Swallowed failure or subsequent transport'}
Case 'coordinator-propagates' {$before=$calls;$caught=$false;try{Invoke-ProcessFeedbackAndResponse $reviewer $developer -GlobalState $GlobalState}catch{$caught=$true};Assert ($caught -and $calls -eq ($before+1)) 'Coordinator swallowed failure';Assert ($GlobalState.LastpydevCode -eq 'x = 1' -and $GlobalState.FileVersion -eq 2) 'Draft lost'}
Case 'empty-draft-preserves' {$caught=$false;try{Save-AndUpdateCode -response '' -GlobalState $GlobalState}catch{$caught=$true};Assert ($caught -and $GlobalState.LastpydevCode -eq 'x = 1' -and $GlobalState.FileVersion -eq 2) 'Empty draft overwritten'}
Case 'rejected-export-preserves' {$caught=$false;try{Save-AndUpdateCode -response ('```python'+"`nx=2`n"+'```'+"`n"+'```python'+"`ny=3`n"+'```') -GlobalState $GlobalState}catch{$caught=$true};Assert ($caught -and $GlobalState.LastpydevCode -eq 'x = 1' -and $GlobalState.FileVersion -eq 2) 'Rejected export overwritten'}
Case 'legacy-not-recorded' {$p=Join-Path $EvidenceRoot legacy.xml;[pscustomobject]@{UserInput='synthetic'}|Export-Clixml $p;$s=Get-ProjectState $p;Assert ($s.WorkflowOutcome -eq 'NotRecorded' -and $s.FailedStage -eq '' -and $s.WorkflowErrorCode -eq '' -and $s.ReducedWorkflow -eq $false) 'Invented historical success or reduced default'}
Case 'save-existing-destination-fails' {$p=Join-Path $EvidenceRoot destination;New-Item -ItemType Directory $p|Out-Null;$s=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot;WorkflowOutcome='Partial';FailedStage='Analyst/Developer';WorkflowErrorCode='StageFailed'};$ok=Save-ProjectState $p $s;Assert ($ok -eq $false -and $s.WorkflowOutcome -eq 'Partial') 'Failed save claimed success or cleared failure'}
Case 'final-failed-save-not-completed' {
 $text=[IO.File]::ReadAllText($source);$start=$text.LastIndexOf('$saved = Save-ProjectState');$end=$text.IndexOf('# Ensure to reset',$start)
 $script:GlobalState|Add-Member WorkflowOutcome 'Completed' -Force;$script:GlobalState|Add-Member FailedStage '' -Force;$script:GlobalState|Add-Member WorkflowErrorCode '' -Force
 $ProjectfilePath=Join-Path $EvidenceRoot destination
 $output=& ([scriptblock]::Create($text.Substring($start,$end-$start))) 6>&1 3>&1
 Assert ($GlobalState.WorkflowOutcome -ne 'Completed' -and ($output -join ' ') -notmatch 'Workflow outcome: Completed|Your progress on Project has been saved') 'Finale claimed completed after failed save'
}
$rows|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot results.json) -Encoding UTF8
if($rows.Count -ne 8 -or @($rows|Where-Object {-not $_.pass}).Count){exit 1}
