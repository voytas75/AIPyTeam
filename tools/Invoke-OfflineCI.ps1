param(
    [Parameter(Mandatory=$true)][string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceRoot
)
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path $RepositoryRoot).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
if ($EvidenceRoot.TrimEnd('\','/') -eq $RepositoryRoot.TrimEnd('\','/') -or
    $EvidenceRoot.StartsWith($RepositoryRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'EvidenceRoot must be outside RepositoryRoot'
}
if (Test-Path $EvidenceRoot) { throw 'EvidenceRoot must be fresh' }
New-Item -ItemType Directory $EvidenceRoot | Out-Null
$artifacts = Join-Path $EvidenceRoot 'artifacts'
New-Item -ItemType Directory $artifacts | Out-Null
$source = Join-Path $RepositoryRoot 'AIPyTeam.ps1'
$sourceHash = (Get-FileHash $source -Algorithm SHA256).Hash
$rows = New-Object Collections.Generic.List[object]
$parses = @()
$failed = $false
# Only repository-owned scripts; evidence and generated fixtures stay outside it.
foreach ($file in Get-ChildItem $RepositoryRoot -Filter '*.ps1' -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }) {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    $parses += @{path=$file.FullName.Substring($RepositoryRoot.Length);errors=$errors.Count}
    if ($errors.Count) { $failed=$true }
}
$parses | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $artifacts 'parsers.json') -Encoding UTF8
$suites = @(
    @{name='WorkflowOutcome';parameter='RepositoryRoot';count=8;receipt='results.json'},
    @{name='AzureDefaults';parameter='RepositoryRoot';count=12;receipt='receipt.json'},
    @{name='Stabilization';parameter='RepositoryRoot';count=13;receipt='results.json'},
    @{name='AzureResponses';parameter='SourcePath';count=16;receipt='receipt.json'},
    @{name='ResponsesHttpError';parameter='SourcePath';count=4;receipt='receipt.json'},
    @{name='PythonExportIntegrity';parameter='RepositoryRoot';count=11;receipt='receipt.json'},
    @{name='WorkflowModes';parameter='RepositoryRoot';count=21;receipt='receipt.json'},
    @{name='LlamaCpp';parameter='RepositoryRoot';count=39;receipt='receipt.json'},
    @{name='DependencyStartup';parameter='RepositoryRoot';count=4;receipt='receipt.json'},
    @{name='PromptContracts';parameter='RepositoryRoot';count=12;receipt='receipt.json'},
    @{name='PromptRequestChain';parameter='RepositoryRoot';count=6;receipt='receipt.json'}
)
# Fresh native process per suite. Never inspect inherited credential values.
$wrapper = Join-Path $EvidenceRoot 'child.ps1'
@'
param($Runner,$ParameterName,$Target,$OutputRoot)
$ErrorActionPreference='Stop'
foreach($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
    if ($name -match '^(PSAOAI_|AZURE_|OPENAI_|ANTHROPIC_|OLLAMA_|LMSTUDIO_|LLAMACPP_|GOOGLE_API_|GEMINI_API_|HF_TOKEN$)') {
        [Environment]::SetEnvironmentVariable($name,$null,'Process')
    }
}
$env:PSModulePath=Join-Path $PSHOME 'Modules'
function global:Read-Host { throw 'Offline CI forbids interactive input' }
function global:Import-Module { throw 'Offline CI forbids external module imports' }
function global:Find-Module { throw 'Offline CI forbids Gallery access' }
function global:Find-Script { throw 'Offline CI forbids Gallery access' }
function global:Install-Module { throw 'Offline CI forbids installations' }
function global:Install-Script { throw 'Offline CI forbids installations' }
function global:Invoke-WebRequest { throw 'Offline CI forbids unguarded HTTP' }
function global:Invoke-RestMethod { throw 'Offline CI forbids unguarded HTTP' }
$args=@{EvidenceRoot=$OutputRoot};$args[$ParameterName]=$Target
. $Runner @args
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
'@ | Set-Content $wrapper -Encoding UTF8
$native = (Get-Process -Id $PID).Path
if (-not $failed) {
    foreach ($suite in $suites) {
        $output = Join-Path $EvidenceRoot $suite.name
        $runner = Join-Path $RepositoryRoot ('tools/tests/Test-'+$suite.name+'.ps1')
        $target = if ($suite.parameter -eq 'SourcePath') {$source} else {$RepositoryRoot}
        $log = Join-Path $artifacts ($suite.name+'.log')
        $code=$null; $count=0; $pass=$false; $errorText=$null
        try {
            & $native -NoProfile -NonInteractive -File $wrapper -Runner $runner -ParameterName $suite.parameter -Target $target -OutputRoot $output *> $log
            $code=$LASTEXITCODE
            if ($code -ne 0) { throw "Native child exited $code" }
            $receiptPath=Join-Path $output $suite.receipt
            $receipt=Get-Content $receiptPath -Raw | ConvertFrom-Json
            $cases=if ($suite.receipt -eq 'results.json') {@($receipt)} else {@($receipt.cases)}
            $count=$cases.Count
            if ($count -ne $suite.count -or @($cases | Where-Object { $_.pass -isnot [bool] -or $_.pass -ne $true }).Count) { throw 'Receipt count/pass mismatch' }
            if ($suite.receipt -eq 'receipt.json' -and $receipt.sourceHash -ne $sourceHash) { throw 'Receipt source hash mismatch' }
            if ($receipt.PSObject.Properties.Name -contains 'parseErrors' -and $receipt.parseErrors -ne 0) { throw 'Receipt parser failure' }
            Copy-Item $receiptPath (Join-Path $artifacts ($suite.name+'.json'))
            $pass=$true
        } catch { $failed=$true; $errorText=$_.Exception.Message }
        $rows.Add(@{suite=$suite.name;expected=$suite.count;actual=$count;exitCode=$code;pass=$pass;error=$errorText})
    }
}
if ((Get-FileHash $source).Hash -ne $sourceHash) { $failed=$true }
@{runtime=$PSVersionTable.PSVersion.ToString();native=$native;sourceHash=$sourceHash;sourceUnchanged=((Get-FileHash $source).Hash -eq $sourceHash);pass=(-not $failed);suites=@($rows.ToArray());scope='Nine preserved suites plus native prompt contracts and original-filepath request chains; no real provider requests'} |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $artifacts 'summary.json') -Encoding UTF8
if ($failed) { exit 1 }
Write-Host ('Offline CI passed: {0} suites, {1} cases.' -f $rows.Count, ($rows | ForEach-Object { $_.actual } | Measure-Object -Sum).Sum)
