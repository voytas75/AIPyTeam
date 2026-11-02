param([string]$RepositoryRoot,[string]$EvidenceRoot,[string]$EntryCase)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$source=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
if(-not $EntryCase){
 $native=(Get-Process -Id $PID).Path
 $rows=@()
 foreach($case in 'fresh','loaded-eligible','loaded-old','only-old'){
  $out=Join-Path $EvidenceRoot $case
  & $native -NoProfile -NonInteractive -File $PSCommandPath -RepositoryRoot $RepositoryRoot -EvidenceRoot $out -EntryCase $case *> (Join-Path $EvidenceRoot ($case+'.log'))
  $code=$LASTEXITCODE
  $receipt=Get-Content (Join-Path $out 'entrypoint.json') -Raw|ConvertFrom-Json
  $rows+=@{name=$case;pass=($code -eq 0 -and $receipt.pass -eq $true);exitCode=$code;detail=$receipt}
 }
 @{sourceHash=(Get-FileHash $source).Hash;cases=$rows;dependencies='owned fixtures; real native module loader'}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot 'receipt.json') -Encoding UTF8
 if(@($rows|Where-Object {-not $_.pass}).Count){exit 1};exit 0
}
# A child owns every dependency path; no installed PSAOAI or Gallery resolution.
Remove-Item Function:\Import-Module -ErrorAction SilentlyContinue
$env:LOCALAPPDATA=Join-Path $EvidenceRoot 'local'
New-Item -ItemType Directory -Force $env:LOCALAPPDATA|Out-Null
$env:DEPENDENCY_COUNTER=Join-Path $env:LOCALAPPDATA 'imports.txt'
$env:DEPENDENCY_MARKER=Join-Path $env:LOCALAPPDATA 'banner.txt'
$env:PSAOAI_BANNER='fixture-unchanged'
$modules=Join-Path $EvidenceRoot 'modules'
$oldModules=Join-Path $EvidenceRoot 'old-modules'
function Fixture($root,$name,$version){
 $dir=Join-Path (Join-Path $root $name) $version
 New-Item -ItemType Directory -Force $dir|Out-Null
 "@{RootModule='$name.psm1';ModuleVersion='$version';GUID='a7130c79-7a1f-46b7-8fd2-682373fb4111'}"|Set-Content (Join-Path $dir "$name.psd1") -Encoding UTF8
 $text=if($name -eq 'PSAOAI'){
 @'
Add-Content $env:DEPENDENCY_COUNTER $ExecutionContext.SessionState.Module.Version.ToString()
Add-Content $env:DEPENDENCY_MARKER 'PSAOAI startup banner marker'
Write-Host 'PSAOAI startup banner marker'
'@
 }else{''}
 $text=$text.Replace('$ExecutionContext.SessionState.Module.Version.ToString()', "'$version'")
 $text|Set-Content (Join-Path $dir "$name.psm1") -Encoding UTF8
 return (Join-Path $dir "$name.psd1")
}
$eligible=Fixture $modules 'PSAOAI' '0.7.0'
$old=Fixture $oldModules 'PSAOAI' '0.3.1'
$null=Fixture $modules 'PowerHTML' '0.2.0'
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+(Join-Path $PSHOME 'Modules')
if($EntryCase -eq 'only-old'){
 Remove-Item (Split-Path $eligible) -Recurse
 $env:PSModulePath=$oldModules+[IO.Path]::PathSeparator+$env:PSModulePath
}
if($EntryCase -eq 'loaded-old'){Microsoft.PowerShell.Core\Import-Module $old}
if($EntryCase -eq 'loaded-eligible'){Microsoft.PowerShell.Core\Import-Module $eligible}
$beforeImports=if(Test-Path $env:DEPENDENCY_COUNTER){@(Get-Content $env:DEPENDENCY_COUNTER).Count}else{0}
function UserHash {
 $e=[Environment]::GetEnvironmentVariables('User')
 $text=(@($e.Keys|Sort-Object -CaseSensitive)|ForEach-Object {"$_=$($e[$_])"}) -join "`n"
 $sha=[Security.Cryptography.SHA256]::Create()
 try{[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))}finally{$sha.Dispose()}
}
$before=UserHash
$global:reads=0;$global:transports=0
function global:Read-Host {$global:reads++;throw 'DEPENDENCY_INPUT_SENTINEL'}
function global:Find-Module {throw 'Gallery forbidden'}
function global:Find-Script {throw 'Gallery forbidden'}
function global:Install-Module {throw 'Install forbidden'}
function global:Invoke-RestMethod {$global:transports++;throw 'Transport forbidden'}
function global:Invoke-WebRequest {$global:transports++;throw 'Transport forbidden'}
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic'
$errorText=$null
try{& $source -DeploymentChat 'synthetic' -NORAG -LogFolder $EvidenceRoot}catch{$errorText=$_.Exception.Message}
$imports=@(Get-Content $env:DEPENDENCY_COUNTER|ForEach-Object {[string]$_})
$markers=@(Get-Content $env:DEPENDENCY_MARKER)
$loaded=@(Get-Module PSAOAI|ForEach-Object {$_.Version.ToString()})
$expected=if($EntryCase -eq 'loaded-old'){2}else{1}
$eligibleLoaded=@(Get-Module PSAOAI|Where-Object {$_.Version -ge [version]'0.3.2'}).Count -gt 0
$pass=($imports.Count -eq $expected -and $markers.Count -eq $expected -and $global:transports -eq 0 -and (UserHash) -eq $before -and $env:PSAOAI_BANNER -ceq 'fixture-unchanged')
if($EntryCase -eq 'only-old'){$pass=$pass -and $global:reads -eq 0 -and -not $eligibleLoaded}else{$pass=$pass -and $global:reads -eq 1 -and $errorText -eq 'DEPENDENCY_INPUT_SENTINEL' -and $eligibleLoaded}
@{pass=[bool]$pass;case=$EntryCase;imports=$imports;markers=$markers.Count;beforeImports=$beforeImports;newImports=($imports.Count-$beforeImports);loaded=$loaded;reads=$global:reads;transports=$global:transports;error=$errorText;UserEnvironmentUnchanged=((UserHash) -eq $before);bannerSettingUnchanged=($env:PSAOAI_BANNER -ceq 'fixture-unchanged');runtime=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot 'entrypoint.json') -Encoding UTF8
if(-not $pass){exit 1}
