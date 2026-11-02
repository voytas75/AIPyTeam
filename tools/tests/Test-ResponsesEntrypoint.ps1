param([string]$RepositoryRoot,[string]$EvidenceRoot,[switch]$Resume,[switch]$RetainedResponse,[switch]$DefaultAzure,[ValidateSet('Responses','ChatCompletions','Legacy')][string]$RecoveryProtocol='Responses',[switch]$PartialRecovery)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$modules=Join-Path $EvidenceRoot 'modules'
foreach($name in 'PSAOAI','PowerHTML'){$dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null;"@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}"|Out-File (Join-Path $dir "$name.psd1") -Encoding utf8;''|Out-File (Join-Path $dir "$name.psm1") -Encoding utf8}
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-key'
$global:posts=0
function global:Find-Script {param($Name,$ErrorAction) @{Version='0.0.3'}}
function global:Read-Host {param($Prompt) 'Q'}
function global:Invoke-WebRequest {throw 'Unexpected transport'}
function global:Invoke-RestMethod {param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction,$ContentType)
 if($Resume){throw 'Recovery HTTP forbidden'}
 if($Uri -ne 'https://fixture.invalid/openai/v1/responses' -or $Method -ne 'POST' -or $Headers['api-key'] -ne 'synthetic-key'){throw 'Unexpected Responses transport'}
 $b=$Body|ConvertFrom-Json
 if($b.max_output_tokens -ne 256 -or $TimeoutSec -ne 60 -or $b.store -ne $false -or $b.stream -ne $false -or $b.model -ne 'opaque-alias'){throw 'Budget/payload mismatch'}
 $global:posts++
 if($RetainedResponse){return @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/fixtures/developer-full120-response10.txt'))})})}}
 @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text=('4. Python code:'+"`n"+'```python'+"`nx = 1`n"+'```'+"`n5. Usage Example:`n"+'```python'+"`nprint(x)`n"+'```')})})}
}
$before=[Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
if($Resume){
 $folder=Join-Path $EvidenceRoot project;New-Item -ItemType Directory -Force $folder|Out-Null
 $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$EvidenceRoot;MaxTokens=256;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$false;LLMProvider='AzureOpenAI';AzureOpenAIProtocol='Responses';AzureResponsesTimeoutSec=60}
 if($PartialRecovery){$state|Add-Member WorkflowOutcome Partial;$state|Add-Member FailedStage 'Analyst/Developer';$state|Add-Member WorkflowErrorCode StageFailed}
 $xml=Join-Path $folder Project.xml;$state|Export-Clixml $xml
 if($RecoveryProtocol -eq 'Legacy'){$state.PSObject.Properties.Remove('AzureOpenAIProtocol');$state.Stream=$true}
 elseif($RecoveryProtocol -eq 'ChatCompletions'){$state.AzureOpenAIProtocol='ChatCompletions';$state.Stream=$true}
 $state|Export-Clixml $xml
 if($RecoveryProtocol -eq 'Responses'){& $entry -LoadProjectStatus $xml -DeploymentChat opaque-alias -AzureOpenAIProtocol ChatCompletions}
 else{& $entry -LoadProjectStatus $xml -DeploymentChat opaque-alias}
}else{
 $selection=if($DefaultAzure){@{}}else{@{LLMProvider='AzureOpenAI';AzureOpenAIProtocol='Responses';Stream=$false}}
 & $entry -UserInput 'Synthetic offline draft' -AzureResponsesTimeoutSec 60 -MaxTokens 256 -DeploymentChat opaque-alias -NORAG -NOPM -NODocumentator -NOTips -LogFolder $EvidenceRoot @selection
}
$after=[Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress
if($before -ne $after){throw 'User environment changed'}
$projects=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)
if($projects.Count -ne 1){throw 'Project save missing'}
$saved=Import-Clixml $projects[0].FullName
$expectedProtocol=if($Resume -and $RecoveryProtocol -ne 'Responses'){'ChatCompletions'}else{'Responses'}
$expectedStream=($Resume -and $RecoveryProtocol -ne 'Responses')
if($saved.AzureOpenAIProtocol -ne $expectedProtocol -or $saved.Stream -ne $expectedStream -or $saved.AzureResponsesTimeoutSec -ne 60 -or $saved.LLMProvider -ne 'AzureOpenAI'){throw 'Saved protocol/stream/budget changed'}
if($PartialRecovery){if($saved.WorkflowOutcome -ne 'Partial' -or $saved.FailedStage -ne 'Analyst/Developer' -or $saved.WorkflowErrorCode -ne 'StageFailed'){throw 'Recovery cleared partial outcome'}}
elseif($Resume){if($saved.WorkflowOutcome -ne 'NotRecorded'){throw 'Recovery invented historical completion'}}
else{if($saved.WorkflowOutcome -ne 'Completed' -or $saved.FailedStage -or $saved.WorkflowErrorCode){throw 'Success outcome incorrect'}}
$final=Join-Path $saved.TeamDiscussionDataFolder TheCodeF.py
$code=Get-Content $final -Raw
if($RetainedResponse){if($code -notmatch 'def greet' -or $code -notmatch 'def main' -or $code -match 'import greet|subprocess|unittest|Path\("greet.py"\)'){throw 'Retained export contaminated'};if($saved.LastpydevCode.Trim() -ne $code.Trim()){throw 'Saved production mismatch'}}
elseif($code -notmatch '(?m)^x = 1' -or $code -match 'print\(x\)'){throw 'Export contaminated'}
if(($Resume -and $global:posts -ne 0) -or (-not $Resume -and $global:posts -ne 10)){throw 'Dispatch count mismatch'}
@{pass=$true;resume=[bool]$Resume;defaultAzure=[bool]$DefaultAzure;recoveryProfile=$RecoveryProtocol;stream=$saved.Stream;posts=$global:posts;sourceHash=(Get-FileHash $entry).Hash;protocol=$saved.AzureOpenAIProtocol;timeout=$saved.AzureResponsesTimeoutSec;project=$projects[0].FullName;final=$final;dependencies='owned fixtures';UserEnvironmentUnchanged=$true}|ConvertTo-Json|Out-File (Join-Path $EvidenceRoot entrypoint.json) -Encoding utf8
