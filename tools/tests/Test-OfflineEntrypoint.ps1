param([string]$RepositoryRoot,[string]$EvidenceRoot,[switch]$Resume)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
# Owned dependency fixtures, not qualification of installed modules.
$modules=Join-Path $EvidenceRoot 'modules'
foreach($name in 'PSAOAI','PowerHTML') { $dir=Join-Path $modules $name; New-Item -ItemType Directory -Force $dir | Out-Null; "@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}" | Out-File (Join-Path $dir "$name.psd1") -Encoding utf8; '' | Out-File (Join-Path $dir "$name.psm1") -Encoding utf8 }
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
$env:OPENAI_API_BASE='http://controlled.invalid/v1/'
$env:OPENAI_API_KEY='synthetic-key'
$global:offlinePosts=0
function global:Find-Script { param($Name,$ErrorAction) return @{Version='0.0.3'} }
function global:Read-Host { param($Prompt) return 'Q' }
function global:Invoke-WebRequest { throw 'Unexpected HTTP transport' }
function global:Invoke-RestMethod { param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction)
 if($Uri -eq 'http://controlled.invalid/v1/models') {if($Headers.Authorization -ne 'Bearer synthetic-key'){throw 'discovery auth missing'};return @{data=@(@{id='synthetic-model'})}}
 if($Uri -eq 'http://controlled.invalid/v1/chat/completions' -and $Method -eq 'POST'){$global:offlinePosts++; return @{Choices=@(@{message=@{content=('4. Python code:' + "`n" + '```python' + "`nx = 1`n" + '```' + "`n5. Usage Example:`n" + '```python' + "`nprint(x)`n" + '```')}})}}
 throw "Unexpected transport $Method $Uri"
}
$before=[Environment]::GetEnvironmentVariables('User') | ConvertTo-Json -Compress
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
if($Resume){
 $folder=Join-Path $EvidenceRoot 'project';New-Item -ItemType Directory -Force $folder|Out-Null
 $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$EvidenceRoot;MaxTokens=100;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$false;LLMProvider='LMStudio'}
 $xml=Join-Path $folder 'Project.xml';$state|Export-Clixml $xml
 & $entry -LoadProjectStatus $xml
}else{ & $entry -UserInput 'Synthetic offline draft' -LLMProvider LMStudio -Stream $false -NORAG -NOPM -NODocumentator -NOTips -LogFolder $EvidenceRoot }
$after=[Environment]::GetEnvironmentVariables('User') | ConvertTo-Json -Compress
if($before -ne $after){throw 'User environment changed'}
$projects=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)
if($projects.Count -ne 1){throw 'Project save missing or ambiguous'}
$saved=Import-Clixml $projects[0].FullName
if($saved.LLMProvider -ne 'LMStudio'){throw 'provider not preserved'}
$final=Join-Path $saved.TeamDiscussionDataFolder 'TheCodeF.py'
if(-not(Test-Path $final)){throw 'final Python export missing'}
$code=Get-Content $final -Raw
if($code -notmatch '(?m)^x = 1' -or $code -match 'print\(x\)'){throw 'draft contaminated or empty'}
if($Resume -and $global:offlinePosts -ne 0){throw 'resume dispatched unexpected POST'}
if(-not $Resume -and $global:offlinePosts -le 0){throw 'fresh path did not dispatch'}
[pscustomobject]@{pass=$true;resume=[bool]$Resume;posts=$global:offlinePosts;project=$projects[0].FullName;final=$final;dependencies='owned fixtures';UserEnvironmentUnchanged=$true} | ConvertTo-Json | Out-File (Join-Path $EvidenceRoot 'entrypoint.json') -Encoding utf8
