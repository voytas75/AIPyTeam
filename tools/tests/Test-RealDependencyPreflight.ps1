param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceRoot,[ValidateSet('Import','Entry')][string]$Mode='Import')
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
function HashText([string]$Text) { $s=[Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() } finally {$s.Dispose()} }
function UserSnapshot { $e=[Environment]::GetEnvironmentVariables('User'); $rows=@($e.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{name=[string]$_;valueHash=(HashText ([string]$e[$_]))} }); HashText ($rows | ConvertTo-Json -Compress) }
function Inventory { @(Get-Module -ListAvailable PSAOAI,PowerHTML | ForEach-Object { $m=$_; $root=Split-Path $m.Path; [pscustomobject]@{name=$m.Name;version=$m.Version.ToString();path=$m.Path;files=@(Get-ChildItem $root -File -Recurse | Sort-Object FullName | ForEach-Object { [pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash} })} }) }
$before=UserSnapshot
$inventory=Inventory
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
$sourceHash=(Get-FileHash $entry).Hash
$global:preflightBootstrap=0
$global:preflightTransport=@()
$global:preflightDiagnostic=$null
$phase='configuration'
# All settings are Process-only and synthetic. Do not inspect inherited provider credentials.
$env:PSAOAI_BANNER='0'
$env:PSAOAI_API_AZURE_OPENAI_APIVERSION='2024-10-21'
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://synthetic.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT='synthetic'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic'
$env:OPENAI_API_BASE='http://controlled.invalid/v1/'
$env:OPENAI_API_KEY='synthetic'
function global:Find-Module { [CmdletBinding()]param($Name,$Repository) $global:preflightBootstrap++; [pscustomobject]@{Version=[version]'0.7.0'} }
function global:Stop-PreflightTransport { param($Command,$Method,$Uri) $global:preflightTransport+= [pscustomobject]@{command=$Command;method=[string]$Method;uri=[string]$Uri}; try {throw [InvalidOperationException]::new('PREFLIGHT_TRANSPORT_SENTINEL')} catch { $global:preflightDiagnostic=[pscustomobject]@{type=$_.Exception.GetType().FullName;message='PREFLIGHT_TRANSPORT_SENTINEL';stack=$_.ScriptStackTrace;phase='pre-discovery'}; throw } }
function global:Invoke-RestMethod { [CmdletBinding()]param($Uri,$Method,$Headers,$Body,$TimeoutSec) Stop-PreflightTransport 'Invoke-RestMethod' $Method $Uri }
function global:Invoke-WebRequest { [CmdletBinding()]param($Uri,$Method,$Headers,$Body,$TimeoutSec,[switch]$UseBasicParsing) Stop-PreflightTransport 'Invoke-WebRequest' $Method $Uri }
function global:Find-Script { [CmdletBinding()]param($Name) throw 'Unexpected script bootstrap' }
function global:Read-Host { param($Prompt) throw 'Unexpected interactive input' }
$failure=$null;$loaded=@();$outcome='FAILED'
try {
 $phase='PowerHTML-unmodified-import'
 $html=@($inventory | Where-Object name -eq 'PowerHTML')[0]
 if(-not $html){throw 'PowerHTML not installed'}
 Import-Module $html.path -Force
 $phase='PSAOAI-guarded-import'
 $psa=@($inventory | Where-Object name -eq 'PSAOAI')[0]
 if(-not $psa){throw 'PSAOAI not installed'}
 Import-Module $psa.path -Force
 $loaded=@(Get-Module PSAOAI,PowerHTML | Select-Object Name,@{n='version';e={$_.Version.ToString()}},Path,@{n='commands';e={$_.ExportedCommands.Count}})
 if($loaded.Count -ne 2){throw 'Actual module load missing'}
 if($Mode -eq 'Entry') {
  $phase='original-entry'
  & $entry -UserInput 'Synthetic preflight only' -DeploymentChat 'synthetic' -LLMProvider LMStudio -Stream $false -NORAG -NOPM -NODocumentator -NOTips -LogFolder $EvidenceRoot | Out-Null
  throw 'Original entry returned without sentinel'
 }
 $outcome='PASS_IMPORT'
} catch {
 $failure=[pscustomobject]@{phase=$phase;type=$_.Exception.GetType().FullName;message='Sanitized non-sentinel error; see type/stack';stack=$_.ScriptStackTrace;errorId=$_.FullyQualifiedErrorId}
 if($_.Exception.Message -eq 'PREFLIGHT_TRANSPORT_SENTINEL') {$failure.message='PREFLIGHT_TRANSPORT_SENTINEL'}
 if($Mode -eq 'Entry' -and $global:preflightTransport.Count -eq 1 -and $global:preflightTransport[0].method -eq 'GET' -and $global:preflightTransport[0].uri -eq 'http://controlled.invalid/v1/models') {$outcome='PASS_PRE_HTTP_STOP'}
}
$after=UserSnapshot
$afterInventory=Inventory
$unchanged=(($inventory | ConvertTo-Json -Depth 8 -Compress) -eq ($afterInventory | ConvertTo-Json -Depth 8 -Compress))
$receipt=[pscustomobject]@{runtime=$PSVersionTable.PSVersion.ToString();mode=$Mode;outcome=$outcome;phase=$phase;loaded=$loaded;bootstrapGuardCalls=$global:preflightBootstrap;transport=$global:preflightTransport;transportDiagnostic=$global:preflightDiagnostic;error=$failure;userBeforeHash=$before;userAfterHash=$after;userUnchanged=($before -eq $after);sourceBeforeHash=$sourceHash;sourceAfterHash=(Get-FileHash $entry).Hash;modulesUnchanged=$unchanged;inventory=$inventory;limits='PSAOAI Find-Module guarded; PowerHTML import unmodified; command-level HTTP sentinel, not OS/network sandbox; direct .NET transports not intercepted. Selected inspected startup stops before HTTP dispatch; no provider acceptance. User hashes detect lasting changes, not transient restored writes.'}
$receipt | ConvertTo-Json -Depth 10 | Out-File (Join-Path $EvidenceRoot 'receipt.json') -Encoding utf8
if($outcome -like 'PASS*' -and $before -eq $after -and $unchanged -and $sourceHash -eq (Get-FileHash $entry).Hash) {exit 0} else {exit 1}
