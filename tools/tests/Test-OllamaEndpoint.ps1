param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Force -Path $EvidenceRoot
$source = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'AIPyTeam.ps1'))
$tokens=$null; $errors=$null
$null = [System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Product parser errors' }
$start = $source.IndexOf('    $script:ollamaEndpoint =', $source.IndexOf('#region ollama'))
$end = $source.IndexOf('    if (-not (Test-OllamaAPI))', $start)
if ($start -lt 0 -or $end -le $start) { throw 'Startup extraction anchor missing' }
$section = $source.Substring($start,$end-$start)
if ($section -match 'SetEnvironmentVariable|Machine') { throw 'Unexpected environment write/scope' }
# Replace only environment reads in the original source; never consult actual stores.
$section = $section -replace '\$env:OLLAMA_ENDPOINT', "(Get-FixtureEnvironment 'OLLAMA_ENDPOINT' 'Process')"
$section = $section -replace '\$env:OLLAMA_HOST', "(Get-FixtureEnvironment 'OLLAMA_HOST' 'Process')"
$section = $section -replace '\[Environment\]::GetEnvironmentVariable', 'Get-FixtureEnvironment'
# Static method argument syntax becomes the fixture function's positional arguments.
$section = $section -replace "Get-FixtureEnvironment\('([^']+)',\s*'([^']+)'\)", "(Get-FixtureEnvironment '`$1' '`$2')"
$fixture = Join-Path $EvidenceRoot 'selection.ps1'
[IO.File]::WriteAllText($fixture,$section)
function Get-FixtureEnvironment { param($Name,$Scope) $script:reads.Add("$Name/$Scope"); return $script:settings["$Name/$Scope"] }
$cases = @(
 @{name='endpoint-process';ep='http://endpoint.invalid';expected='http://endpoint.invalid/'},
 @{name='endpoint-user';eu='http://user-endpoint.invalid';expected='http://user-endpoint.invalid/'},
 @{name='host-process';hp='http://host.invalid:11434';expected='http://host.invalid:11434/'},
 @{name='host-user';hu='http://user-host.invalid';expected='http://user-host.invalid/'},
 @{name='neither';expected='http://localhost:11434/'},
 @{name='both-process';ep='http://endpoint.invalid/';hp='http://host.invalid/';expected='http://endpoint.invalid/'},
 @{name='user-endpoint-before-process-host';eu='http://user-endpoint.invalid';hp='http://host.invalid';expected='http://user-endpoint.invalid/'},
 @{name='process-endpoint-before-user-endpoint';ep='http://endpoint.invalid';eu='http://user-endpoint.invalid';expected='http://endpoint.invalid/'},
 @{name='process-host-before-user-host';hp='http://host.invalid';hu='http://user-host.invalid';expected='http://host.invalid/'},
 @{name='whitespace-endpoint-falls-to-user';ep='   ';eu=' http://user-endpoint.invalid/// ';expected='http://user-endpoint.invalid/'},
 @{name='blank-endpoints-host';ep=" `t ";eu=' ';hp=' http://host.invalid/// ';expected='http://host.invalid/'},
 @{name='all-whitespace-default';ep=' ';eu=' ';hp=' ';hu=' ';expected='http://localhost:11434/'},
 @{name='endpoint-trim-slashes';ep=' http://endpoint.invalid/// ';expected='http://endpoint.invalid/'}
)
$results = foreach ($case in $cases) {
 $script:settings=@{'OLLAMA_ENDPOINT/Process'=$case.ep;'OLLAMA_ENDPOINT/User'=$case.eu;'OLLAMA_HOST/Process'=$case.hp;'OLLAMA_HOST/User'=$case.hu}
 $script:reads=New-Object 'System.Collections.Generic.List[string]'
 $script:ollamaEndpoint=$null
 . $fixture
 [pscustomobject]@{name=$case.name;pass=($script:ollamaEndpoint -ceq $case.expected);reads=@($script:reads.ToArray())}
}
$failed=@($results | Where-Object { -not $_.pass })
$receipt=[pscustomobject]@{runtime=$PSVersionTable.PSVersion.ToString();cases=$results.Count;failed=$failed.Count;pass=($failed.Count -eq 0);sourceSHA256=(Get-FileHash (Join-Path $RepositoryRoot 'AIPyTeam.ps1') -Algorithm SHA256).Hash;results=@($results)}
$receipt | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $EvidenceRoot 'receipt.json') -Encoding UTF8
$receipt | ConvertTo-Json -Depth 6
if ($failed.Count) { exit 1 }
