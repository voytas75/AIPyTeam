param([string]$RepositoryRoot,[string]$EvidenceRoot,[switch]$Resume,[switch]$RetainedResponse,[switch]$DefaultAzure,[ValidateSet('Responses','ChatCompletions','Legacy')][string]$RecoveryProtocol='Responses',[switch]$PartialRecovery,[switch]$NOInteraction,[switch]$ReducedWorkflow,[int]$FailAt=0,[switch]$RejectDeveloper,[switch]$SavedReduced,[switch]$OmitSkipFlags,[switch]$PipelineScalar,[switch]$ConfiguredRAG,[switch]$LMStudio,[switch]$WithKey,[string]$ActualRecovery,[switch]$LateRejected,[switch]$FailedSave)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$modules=Join-Path $EvidenceRoot 'modules'
foreach($name in 'PSAOAI','PowerHTML'){$dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null;"@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}"|Out-File (Join-Path $dir "$name.psd1") -Encoding utf8;''|Out-File (Join-Path $dir "$name.psm1") -Encoding utf8}
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-key'
$global:posts=0;$global:gets=0;$global:webs=0
if($ActualRecovery){$Resume=$true}
$env:OPENAI_API_BASE='https://fixture.invalid/v1/'
$env:OPENAI_API_KEY=if($WithKey){'synthetic-local'}else{''}
$env:AZURE_BING_API_KEY='synthetic-bing';$env:AZURE_BING_SEARCH_ENDPOINT='https://bing.fixture.invalid/'
function Get-UserHash {
 $e=[Environment]::GetEnvironmentVariables('User');$text=(@($e.Keys|Sort-Object -CaseSensitive)|ForEach-Object {"$_=$($e[$_])"}) -join "`n"
 $sha=[Security.Cryptography.SHA256]::Create();([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','')
}
if($ConfiguredRAG){
 'function ConvertFrom-HTML {param([Parameter(ValueFromPipeline=$true)]$InputObject) process {[pscustomobject]@{innerText="Synthetic article"}}};Export-ModuleMember -Function ConvertFrom-HTML'|Set-Content (Join-Path $modules 'PowerHTML/PowerHTML.psm1')
}
if($FailedSave){
 function global:Export-Clixml {
  param([string]$Path,[Parameter(ValueFromPipeline=$true)]$InputObject)
  process {
   [IO.File]::WriteAllText($Path,'existing-state-sentinel')
   $lock=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
   try { Microsoft.PowerShell.Utility\Export-Clixml -Path $Path -InputObject $InputObject -ErrorAction Stop }
   finally { $lock.Dispose() }
  }
 }
}
function global:Find-Script {param($Name,$ErrorAction) @{Version='0.0.3'}}
$global:reads=0
function global:Read-Host {param($Prompt) $global:reads++;if($NOInteraction){throw 'Unexpected interactive input'};'Q'}
function global:Invoke-WebRequest {param($Uri) if($ConfiguredRAG -and $Uri -eq 'https://article.fixture.invalid/'){ $global:webs++;return @{Content='<p>Synthetic article</p>'}};throw 'Unexpected transport'}
function global:Invoke-RestMethod {param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction,$ContentType)
 if($Resume){throw 'Recovery HTTP forbidden'}
 if($LMStudio){
  $auth=if($WithKey){'Bearer synthetic-local'}else{'Bearer lm-studio'}
  if($Headers.Authorization -ne $auth){throw 'Local auth mismatch'}
  if($Uri -eq 'https://fixture.invalid/v1/models' -and $Method -eq 'GET'){$global:gets++;return @{data=@(@{id='local-model'})}}
  if($Uri -ne 'https://fixture.invalid/v1/chat/completions' -or $Method -ne 'POST'){throw 'Local transport mismatch'}
  $b=$Body|ConvertFrom-Json;if($b.model -ne 'local-model' -or $b.stream -or $b.max_tokens -ne 256){throw 'Local payload mismatch'}
  $global:posts++;return @{choices=@(@{message=@{content="4. Python code:`n"+'```python'+"`nx = 1`n"+'```'+"`n5. Usage Example:"}})}
 }
 if($ConfiguredRAG -and $Uri -eq 'https://bing.fixture.invalid/v7.0/search'){
  if($Headers['Ocp-Apim-Subscription-Key'] -ne 'synthetic-bing'){throw 'Bing auth mismatch'}
  $global:gets++;return @{webPages=@{value=@(@{url='https://article.fixture.invalid/';name='Fixture';snippet='Synthetic'})}}
 }
 if($Uri -ne 'https://fixture.invalid/openai/v1/responses' -or $Method -ne 'POST' -or $Headers['api-key'] -ne 'synthetic-key'){throw 'Unexpected Responses transport'}
 $b=$Body|ConvertFrom-Json
 if($b.max_output_tokens -ne 256 -or $TimeoutSec -ne 60 -or $b.store -ne $false -or $b.stream -ne $false -or $b.model -ne 'opaque-alias'){throw 'Budget/payload mismatch'}
 $global:posts++
 if($FailAt -eq $global:posts){throw 'Synthetic stage failure'}
 if(($RejectDeveloper -and $global:posts -eq 2) -or ($LateRejected -and $global:posts -eq 4)){return @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text='No code available'})})}}
 if($RetainedResponse){return @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/fixtures/developer-full120-response10.txt'))})})}}
 @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text=('4. Python code:'+"`n"+'```python'+"`nx = 1`n"+'```'+"`n5. Usage Example:`n"+'```python'+"`nprint(x)`n"+'```')})})}
}
$before=Get-UserHash
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
if($ActualRecovery){
 & $entry -LoadProjectStatus $ActualRecovery -DeploymentChat opaque-alias -NOInteraction -ReducedWorkflow
}elseif($Resume){
 $folder=Join-Path $EvidenceRoot project;New-Item -ItemType Directory -Force $folder|Out-Null
 $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$EvidenceRoot;MaxTokens=256;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$false;LLMProvider='AzureOpenAI';AzureOpenAIProtocol='Responses';AzureResponsesTimeoutSec=60}
 if($PartialRecovery){$state|Add-Member WorkflowOutcome Partial;$state|Add-Member FailedStage 'Analyst/Developer';$state|Add-Member WorkflowErrorCode StageFailed}
 if($SavedReduced){$state|Add-Member ReducedWorkflow $true}
 $xml=Join-Path $folder Project.xml;$state|Export-Clixml $xml
 if($RecoveryProtocol -eq 'Legacy'){$state.PSObject.Properties.Remove('AzureOpenAIProtocol');$state.Stream=$true}
 elseif($RecoveryProtocol -eq 'ChatCompletions'){$state.AzureOpenAIProtocol='ChatCompletions';$state.Stream=$true}
 $state|Export-Clixml $xml
 $resumeArgs=@{}
 if($NOInteraction){$resumeArgs.NOInteraction=$true}
 if($ReducedWorkflow){$resumeArgs.ReducedWorkflow=$true}
 if($RecoveryProtocol -eq 'Responses'){& $entry -LoadProjectStatus $xml -DeploymentChat opaque-alias -AzureOpenAIProtocol ChatCompletions @resumeArgs}
 else{& $entry -LoadProjectStatus $xml -DeploymentChat opaque-alias @resumeArgs}
}else{
 $selection=if($DefaultAzure){@{}}else{@{LLMProvider='AzureOpenAI';AzureOpenAIProtocol='Responses';Stream=$false}}
 if($NOInteraction){$selection.NOInteraction=$true}
 if($ReducedWorkflow){$selection.ReducedWorkflow=$true}
 if(-not $OmitSkipFlags){$selection.NOPM=$true;$selection.NODocumentator=$true}
 if(-not $ConfiguredRAG){$selection.NORAG=$true}
 if($LMStudio){$selection.LLMProvider='LMStudio';$selection.Remove('AzureOpenAIProtocol')}
 if($PipelineScalar){'Synthetic offline draft'| & $entry -AzureResponsesTimeoutSec 60 -MaxTokens 256 -DeploymentChat opaque-alias -NOTips -LogFolder $EvidenceRoot @selection}
 else{& $entry -UserInput 'Synthetic offline draft' -AzureResponsesTimeoutSec 60 -MaxTokens 256 -DeploymentChat opaque-alias -NOTips -LogFolder $EvidenceRoot @selection}
}
$after=Get-UserHash
if($before -ne $after){throw 'User environment changed'}
if($FailedSave){
 $transcript=(Get-ChildItem $EvidenceRoot -Filter '*.txt' -Recurse|ForEach-Object {Get-Content $_.FullName -Raw}) -join "`n"
 $existing=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse);if($existing.Count -ne 1 -or [IO.File]::ReadAllText($existing[0].FullName) -ne 'existing-state-sentinel'){throw 'Failed save overwrote existing target'}
 # Finalizer status is asserted in supervisor original-output log; unsaved Partial cannot be persisted.
 @{pass=$true;posts=$global:posts;reads=$global:reads;sourceHash=(Get-FileHash $entry).Hash;UserHashBefore=$before;UserHashAfter=$after;failure='native Export-Clixml locked existing target';existingTargetPreserved=$true}|ConvertTo-Json|Set-Content (Join-Path $EvidenceRoot entrypoint.json)
 exit 0
}
$projects=if($ActualRecovery){@(Get-Item $ActualRecovery)}else{@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)}
if($projects.Count -ne 1){throw 'Project save missing'}
$saved=Import-Clixml $projects[0].FullName
if($saved.PSObject.Properties['NOInteraction']){throw 'Invocation-only flag persisted'}
if(-not $ActualRecovery -and $saved.ReducedWorkflow -ne [bool]($SavedReduced -or ($ReducedWorkflow -and -not $Resume))){throw 'ReducedWorkflow state/default mismatch'}
$expectedProtocol=if($Resume -and $RecoveryProtocol -ne 'Responses'){'ChatCompletions'}else{'Responses'}
$expectedStream=($Resume -and $RecoveryProtocol -ne 'Responses')
if(-not $LMStudio -and ($saved.AzureOpenAIProtocol -ne $expectedProtocol -or $saved.Stream -ne $expectedStream -or $saved.AzureResponsesTimeoutSec -ne 60 -or $saved.LLMProvider -ne 'AzureOpenAI')){throw 'Saved protocol/stream/budget changed'}
if($PartialRecovery -or $ActualRecovery -or $LateRejected -or ($FailAt -gt 2)){if($saved.WorkflowOutcome -ne 'Partial' -or $saved.FailedStage -ne 'Analyst/Developer' -or $saved.WorkflowErrorCode -ne 'StageFailed'){throw 'Recovery cleared partial outcome'}}
elseif($Resume){if($saved.WorkflowOutcome -ne 'NotRecorded'){throw 'Recovery invented historical completion'}}
elseif($FailAt -or $RejectDeveloper){if($saved.WorkflowOutcome -ne 'Failed' -or $saved.LastpydevCode){throw 'Failure outcome incorrect'}}
else{if($saved.WorkflowOutcome -ne 'Completed' -or $saved.FailedStage -or $saved.WorkflowErrorCode){throw 'Success outcome incorrect'}}
$final=Join-Path $saved.TeamDiscussionDataFolder TheCodeF.py
$code=if(Test-Path $final){Get-Content $final -Raw}else{''}
if($RetainedResponse){if($code -notmatch 'def greet' -or $code -notmatch 'def main' -or $code -match 'import greet|subprocess|unittest|Path\("greet.py"\)'){throw 'Retained export contaminated'};if($saved.LastpydevCode.Trim() -ne $code.Trim()){throw 'Saved production mismatch'}}
elseif(-not ($FailAt -or $RejectDeveloper) -and ($code -notmatch '(?m)^x = 1' -or $code -match 'print\(x\)')){throw 'Export contaminated'}
$expected=if($Resume){0}elseif($FailAt){$FailAt}elseif($LateRejected){4}elseif($ConfiguredRAG){5}elseif($RejectDeveloper -or $ReducedWorkflow){2}else{10}
if($global:posts -ne $expected -or ($NOInteraction -and $global:reads -ne 0)){throw "Dispatch/input count mismatch: posts=$global:posts expected=$expected reads=$global:reads"}
@{pass=$true;resume=[bool]$Resume;defaultAzure=[bool]$DefaultAzure;recoveryProfile=$RecoveryProtocol;stream=$saved.Stream;posts=$global:posts;reads=$global:reads;reduced=$saved.ReducedWorkflow;outcome=$saved.WorkflowOutcome;sourceHash=(Get-FileHash $entry).Hash;protocol=$saved.AzureOpenAIProtocol;timeout=$saved.AzureResponsesTimeoutSec;project=$projects[0].FullName;final=$final;dependencies='owned fixtures';UserEnvironmentUnchanged=$true;UserHashBefore=$before;UserHashAfter=$after;gets=$global:gets;webs=$global:webs;originalEntry=$entry;pipelineScalar=[bool]$PipelineScalar}|ConvertTo-Json|Out-File (Join-Path $EvidenceRoot entrypoint.json) -Encoding utf8
