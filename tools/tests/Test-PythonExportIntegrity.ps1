param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$entry=Join-Path $RepositoryRoot AIPyTeam.ps1
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$t,[ref]$e)
$f=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq Export-AndWritePythonCodeBlocks
. ([scriptblock]::Create($f.Extent.Text))
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath)}
$GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot}
$rows=New-Object Collections.Generic.List[object]
function Assert($ok,$message){if(-not $ok){throw $message}}
function Case($name,[scriptblock]$body){try{& $body;$rows.Add(@{name=$name;pass=$true})}catch{$rows.Add(@{name=$name;pass=$false;error=$_.Exception.Message})}}
function Block($code){'```python'+"`n"+$code+"`n"+'```'}
function Export($text,$name){Export-AndWritePythonCodeBlocks -InputString $text -OutputFilePath (Join-Path $EvidenceRoot ($name+'.py')) -StartDelimiter '```python' -EndDelimiter '```'}
function Reject($text){$path=Join-Path $EvidenceRoot preserve.py;[IO.File]::WriteAllText($path,'sentinel');$before=(Get-FileHash $path).Hash;$out=Export-AndWritePythonCodeBlocks -InputString $text -OutputFilePath $path -StartDelimiter '```python' -EndDelimiter '```';Assert ($out -eq $false -and (Get-FileHash $path).Hash -eq $before) 'ambiguous input accepted/overwritten'}
Case 'captured-response' {
 $fixture=Join-Path $RepositoryRoot 'tools/tests/fixtures/developer-full120-response10.txt'
 Assert ((Get-FileHash $fixture).Hash -eq '51ACA936E0E5D86FFE06FB3554F70F5B7228E4791A761AEC0A534DC53242BDD2') 'retained raw response hash changed'
 $text=[IO.File]::ReadAllText($fixture);Export $text captured|Out-Null
 $code=[IO.File]::ReadAllText((Join-Path $EvidenceRoot captured.py))
 $expected=[regex]::Match($text,'(?s)```python\s*\r?\n(.*?)```').Groups[1].Value.Trim()
 Assert ($code.Trim() -eq $expected) 'captured export contains development tests or loses production'
 Assert ($code -match 'def greet' -and $code -match 'def main' -and $code -notmatch 'import greet|subprocess|unittest|Path\("greet.py"\)') 'production integrity failed'
}
$production="4. Python code`n"+(Block "x = 1")+"`n"+(Block "def helper():`n    return x")
Case 'production-helpers-tests' {$text=$production+"`n### Development-only acceptance tests`n"+(Block 'import missing_test_module')+"`n5. Usage Example`n"+(Block 'print(helper())');Export $text helpers|Out-Null;$code=Get-Content (Join-Path $EvidenceRoot helpers.py) -Raw;Assert ($code -match 'def helper' -and $code -notmatch 'missing_test|print') 'helpers lost/tests retained'}
Case 'legacy-single' {Export (Block 'x = 1') legacy|Out-Null;Assert ((Get-Content (Join-Path $EvidenceRoot legacy.py) -Raw).Trim() -eq 'x = 1') 'legacy changed'}
Case 'all-production-blocks' {Export $production allproduction|Out-Null;Assert ((Get-Content (Join-Path $EvidenceRoot allproduction.py) -Raw) -match 'def helper') 'helper missing'}
Case 'usage-heading-variant' {Export ($production+"`n## 5. **Code Usage:**`n"+(Block 'print(x)')) usage|Out-Null;Assert ((Get-Content (Join-Path $EvidenceRoot usage.py) -Raw) -notmatch 'print') 'Code Usage retained'}
Case 'headings-inside-fences' {Export ("4. Code`n"+(Block "text = '''`n### Development-only acceptance tests`n5. Usage Example`n'''`nx = 1")) fenced|Out-Null;Assert ((Get-Content (Join-Path $EvidenceRoot fenced.py) -Raw) -match 'x = 1') 'fenced heading recognized'}
Case 'ambiguous-unstructured' {Reject ((Block 'x = 1')+"`n"+(Block 'y = 2'))}
Case 'ambiguous-test-heading' {Reject ($production+"`n### Tests`n"+(Block 'import missing_test_module'))}
Case 'production-after-tests' {Reject ($production+"`n### Development-only acceptance tests`n"+(Block 'import missing_test_module')+"`n### Production script`n"+(Block 'y = 2'))}
Case 'tests-without-production' {Reject ("4. Code`n### Development-only acceptance tests`n"+(Block 'import missing_test_module'))}
Case 'multiple-code-headings' {Reject ($production+"`n4. Code`n"+(Block 'y = 2'))}
@{runtime=$PSVersionTable.PSVersion.ToString();sourceHash=(Get-FileHash $entry).Hash;fixtureHash=(Get-FileHash (Join-Path $RepositoryRoot 'tools/tests/fixtures/developer-full120-response10.txt')).Hash;parseErrors=$e.Count;cases=@($rows.ToArray())}|ConvertTo-Json -Depth 6|Out-File (Join-Path $EvidenceRoot receipt.json) -Encoding utf8
if($e.Count -or @($rows|Where-Object {-not $_.pass}).Count){exit 1}
