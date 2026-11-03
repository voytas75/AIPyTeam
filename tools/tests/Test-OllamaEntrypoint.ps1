param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceRoot,[ValidateSet('Host','Endpoint','Default')][string]$Case='Host',[switch]$Resume)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
# Reuse Test-ResponsesEntrypoint's owned modules, state shape and original filepath invocation.
# No extracted product blocks; selected nonstreaming NOInteraction paths only.
function Get-UserHash {
 $e=[Environment]::GetEnvironmentVariables('User');$text=(@($e.Keys|Sort-Object -CaseSensitive)|ForEach-Object {"$_=$($e[$_])"}) -join "`n"
 $sha=[Security.Cryptography.SHA256]::Create();([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','')
}
$before=Get-UserHash
foreach($name in 'OLLAMA_ENDPOINT','OLLAMA_HOST') {
 if(-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name,'User'))){throw "Fixture prerequisite blocked: nonblank User $name; no User mutation permitted"}
}
foreach($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
 if($name -match '^(SERPAPI_|EXA_|SERPER_|PSAOAI_|AZURE_|OPENAI_|ANTHROPIC_|OLLAMA_|LMSTUDIO_|LLAMACPP_)'){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
}
$env:OLLAMA_MODEL='synthetic-model'
$expected= switch($Case){Host {$env:OLLAMA_HOST='  http://host.fixture.invalid:11434///  ';'http://host.fixture.invalid:11434/'} Endpoint {$env:OLLAMA_HOST='http://ignored.fixture.invalid/';$env:OLLAMA_ENDPOINT='  http://endpoint.fixture.invalid///  ';'http://endpoint.fixture.invalid/'} Default {'http://localhost:11434/'}}
$modules=Join-Path $EvidenceRoot modules
foreach($name in 'PSAOAI','PowerHTML'){
 $dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null
 "@{RootModule='$name.psm1';ModuleVersion='0.7.0';GUID='$([guid]::NewGuid())'}"|Out-File (Join-Path $dir "$name.psd1") -Encoding utf8
 ''|Out-File (Join-Path $dir "$name.psm1") -Encoding utf8
}
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+(Join-Path $PSHOME Modules)
$global:requests=New-Object Collections.Generic.List[object]
$global:unexpected=0;$global:reads=0
function global:Read-Host {$global:reads++;throw 'Interactive input forbidden'}
function global:Find-Script {param($Name,$ErrorAction) @{Version='0.0.3'}}
function global:Find-Module {throw 'Gallery forbidden'}
function global:Install-Module {throw 'Installation forbidden'}
function global:Invoke-RestMethod {
 param($Uri,$Method,$Headers,$Body,$TimeoutSec,$ErrorAction)
 $global:requests.Add(@{method="$Method";uri="$Uri";kind='discovery'})
 if($Method -eq 'GET' -and "$Uri" -eq $expected){return 'Ollama is running'}
 if($Method -eq 'GET' -and "$Uri" -eq ($expected+'api/ps')){return @{models=@(@{name='synthetic-model';size=1})}}
 $global:unexpected++;throw 'Unexpected discovery transport'
}
function global:Invoke-WebRequest {
 param($Uri,$Method,$Body,[switch]$UseBasicParsing)
 $global:requests.Add(@{method="$Method";uri="$Uri";kind='completion'})
 if($Resume -or $Method -ne 'POST' -or "$Uri" -ne ($expected+'api/generate')){$global:unexpected++;throw 'Unexpected completion transport'}
 $b=$Body|ConvertFrom-Json
 if($b.model -ne 'synthetic-model' -or $b.stream -ne $false){$global:unexpected++;throw 'Payload mismatch'}
 @{Content=(@{response="4. Python code:`n"+'```python'+"`nx = 1`n"+'```'+"`n5. Usage Example:`n"+'```python'+"`nprint(x)`n"+'```'}|ConvertTo-Json)}
}
$entry=Join-Path $RepositoryRoot AIPyTeam.ps1;$hash=(Get-FileHash $entry).Hash
if($Resume){
 $folder=Join-Path $EvidenceRoot project;New-Item -ItemType Directory -Force $folder|Out-Null
 $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$EvidenceRoot;MaxTokens=256;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$false;LLMProvider='ollama';ReducedWorkflow=$true;WorkflowOutcome='Partial';FailedStage='Analyst/Developer';WorkflowErrorCode='StageFailed'}
 $xml=Join-Path $folder Project.xml;$state|Export-Clixml $xml
 # Deliberately conflicting CLI provider: saved provider must govern initialization.
 & $entry -LoadProjectStatus $xml -LLMProvider LMStudio -DeploymentChat opaque-alias -NOInteraction
}else{
 & $entry -UserInput 'Synthetic offline draft' -LLMProvider ollama -DeploymentChat opaque-alias -NOInteraction -ReducedWorkflow -Stream $false -NORAG -NOPM -NODocumentator -NOTips -LogFolder $EvidenceRoot
}
$after=Get-UserHash
$projects=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)
if($projects.Count -ne 1){throw 'Project save missing or ambiguous'}
$saved=Import-Clixml $projects[0].FullName
$final=Join-Path $saved.TeamDiscussionDataFolder TheCodeF.py;$code=Get-Content $final -Raw
$posts=@($requests|Where-Object {$_.kind -eq 'completion'}).Count
$gets=@($requests|Where-Object {$_.kind -eq 'discovery'}).Count
$expectedPosts=if($Resume){0}else{2}
if($unexpected -or $reads -or $posts -ne $expectedPosts -or $gets -ne 2 -or $before -ne $after -or $saved.LLMProvider -ne 'ollama' -or $code -notmatch '(?m)^x = 1' -or $code -match 'print\(x\)' -or (Get-FileHash $entry).Hash -ne $hash){throw 'Original entry acceptance mismatch'}
if($Resume -and ($saved.WorkflowOutcome -ne 'Partial' -or $saved.LastpydevCode -ne 'x = 1')){throw 'Saved recovery contract mismatch'}
@{pass=$true;case=$Case;resume=[bool]$Resume;sourceHash=$hash;runnerHash=(Get-FileHash $PSCommandPath).Hash;runtime=$PSVersionTable.PSVersion.ToString();entry=$entry;requests=@($requests.ToArray());posts=$posts;gets=$gets;UserHashBefore=$before;UserHashAfter=$after;provider=$saved.LLMProvider;outcome=$saved.WorkflowOutcome;project=$projects[0].FullName;final=$final;scope='Original filepath, owned modules, intercepted cmdlets; no real provider calls, no streaming or OS network isolation'}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $EvidenceRoot entrypoint.json) -Encoding UTF8
