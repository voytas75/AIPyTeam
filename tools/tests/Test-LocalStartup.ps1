param([string]$RepositoryRoot,[string]$EvidenceRoot,[string]$Provider='LMStudio',[switch]$Resume,[switch]$EmptyModels)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
$s=Get-Content (Join-Path $RepositoryRoot 'AIPyTeam.ps1') -Raw
$env:OPENAI_API_BASE='http://controlled.invalid/v1/'
$env:OPENAI_API_KEY='synthetic-key'
$env:OLLAMA_ENDPOINT='http://controlled.invalid/'
$env:OLLAMA_MODEL='synthetic-model'
$GlobalState=[pscustomobject]@{LLMProvider=$Provider}
$LoadProjectStatus=if($Resume){'synthetic.xml'}else{''}
$script:requests=New-Object System.Collections.Generic.List[object]
function Invoke-RestMethod { param($Uri,$Method,$Headers,$ErrorAction) $script:requests.Add([pscustomobject]@{uri="$Uri";auth=$Headers.Authorization}); if($Uri -like '*/models'){ if($EmptyModels){return @{data=@()}}; return @{data=@(@{id='synthetic-model'})} }; if($Uri -like '*/api/ps'){return @{models=@(@{name='synthetic-model';size=1})}}; return 'Ollama is running' }
function Invoke-WebRequest { throw 'Root readiness forbidden' }
function Update-ErrorHandling { param($ErrorRecord,$ErrorContext,$LogFilePath) }
$t=$null;$e=$null;$ast=[System.Management.Automation.Language.Parser]::ParseInput($s,[ref]$t,[ref]$e)
foreach($f in $ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false)){if($f.Extent.Text -match '^function\s'){. ([scriptblock]::Create($f.Extent.Text))}}
$start=$s.IndexOf('#region ollama');$end=$s.IndexOf('#endregion LMStudio',$start)+'#endregion LMStudio'.Length
# Original source section in an owned script file preserves script scope.
$path=Join-Path $EvidenceRoot 'startup-section.ps1';[IO.File]::WriteAllText($path,$s.Substring($start,$end-$start))
# Reject known User setters before execution; do not restore transient writes.
$section=Get-Content $path -Raw
if($section -match 'SetEnvironmentVariable'){throw 'unsafe User write in source section'}
try { . $path } catch { if (-not $EmptyModels -or $_.Exception.Message -notmatch 'No models loaded') { throw }; $script:expectedFailure=$true }
if($EmptyModels -and -not $script:expectedFailure){throw 'empty discovery did not fail closed'}
if($Provider -eq 'LMStudio'){
 if($EmptyModels){if($script:LMStudioModel){throw 'empty discovery accepted'}}
 else {if($script:LMStudioModel -ne 'synthetic-model'){throw 'model not initialized'};if($requests.Count -ne 1 -or $requests[0].uri -ne 'http://controlled.invalid/v1/models' -or $requests[0].auth -ne 'Bearer synthetic-key'){throw 'discovery request mismatch'}}
}else{if($script:ollamaEndpoint -ne 'http://controlled.invalid/' -or $script:ollamaModel -ne 'synthetic-model'){throw 'Ollama configuration missing'}}
[pscustomobject]@{provider=$Provider;resume=[bool]$Resume;empty=[bool]$EmptyModels;pass=$true;requests=@($requests.ToArray())} | ConvertTo-Json -Depth 5 | Out-File (Join-Path $EvidenceRoot 'startup.json') -Encoding utf8
