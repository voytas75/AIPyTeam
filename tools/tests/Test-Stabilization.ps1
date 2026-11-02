param([string]$RepositoryRoot, [string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
$source = Get-Content (Join-Path $RepositoryRoot 'AIPyTeam.ps1') -Raw
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
$results = New-Object System.Collections.Generic.List[object]
function Case($name, [scriptblock]$body) { try { & $body; $results.Add([pscustomobject]@{name=$name;pass=$true;error=''}) } catch { $results.Add([pscustomobject]@{name=$name;pass=$false;error=$_.Exception.Message}) } }
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$functions=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false)
foreach($f in $functions) { if ($f.Extent.Text -match '^function\s') { . ([scriptblock]::Create($f.Extent.Text)) } }
function Update-ErrorHandling { param($ErrorRecord,$ErrorContext,$LogFilePath) }
$GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot;VerbosePrompt=$false}
Case 'parser' { Assert ($errors.Count -eq 0) 'parse errors' }
Case 'dispatch-targets' { foreach($name in 'OllamaCompletion','LMStudioChatCompletion','AzureOpenAIChatCompletion') { Assert ([bool](Get-Command "Invoke-AIPyTeam$name" -ErrorAction SilentlyContinue)) "missing $name" } }
Case 'single-export' { $out=Export-AndWritePythonCodeBlocks -InputString ('```python' + "`nx = 1`n" + '```') -StartDelimiter '```python' -EndDelimiter '```'; Assert ($out -match '(?m)^x = 1') 'top-level indentation'; $out | Out-File (Join-Path $EvidenceRoot 'single.py') -Encoding utf8 }
Case 'section-export' { $text='1. Code:' + "`n" + '```python' + "`nx = 1`n" + '```' + "`n" + '```python' + "`ndef helper():`n    return x`n" + '```' + "`n2. Usage Example:`n" + '```python' + "`nhelper()`n" + '```'; $path=Join-Path $EvidenceRoot 'sections.py'; 'old' | Out-File $path; $out=Export-AndWritePythonCodeBlocks -InputString $text -OutputFilePath $path -StartDelimiter '```python' -EndDelimiter '```'; $code=Get-Content $path -Raw; Assert ($code -notmatch 'old|(?m)^helper\(\)') 'contaminated export'; Assert ($code -match 'def helper') 'helper missing' }
Case 'ambiguous-preserves' { $path=Join-Path $EvidenceRoot 'preserve.py'; 'sentinel' | Out-File $path; $text='```python' + "`nx=1`n" + '```' + "`n" + '```python' + "`ny=2`n" + '```'; $out=Export-AndWritePythonCodeBlocks -InputString $text -OutputFilePath $path -StartDelimiter '```python' -EndDelimiter '```'; Assert ($out -eq $false) 'ambiguous accepted'; Assert ((Get-Content $path -Raw).Trim() -eq 'sentinel') 'overwritten' }
Case 'legacy-load' { $path=Join-Path $EvidenceRoot 'legacy.xml'; [pscustomobject]@{UserInput='synthetic'} | Export-Clixml $path; $state=Get-ProjectState $path; Assert ($state.LLMProvider -eq 'AzureOpenAI') 'legacy provider missing' }
Case 'save-success' { $path=Join-Path $EvidenceRoot 'state.xml'; $ok=Save-ProjectState $path $GlobalState; Assert ($ok -eq $true) 'missing true'; Assert ((Import-Clixml $path).TeamDiscussionDataFolder -eq $EvidenceRoot) 'readback mismatch' }
Case 'save-failure' { $ok=Save-ProjectState (Join-Path $EvidenceRoot 'missing/state.xml') $GlobalState; Assert ($ok -eq $false) 'missing false' }
Case 'save-callers' { Assert ($source -notmatch 'Save-ProjectState[^\r\n]+\r?\n\s*if \((Test-Path|\$ProjectfilePath)') 'caller infers stale success' }
Case 'heading-inside-fence' { $text='```python' + "`n# Code`n# Usage Example`nx = 1`n" + '```'; $out=Export-AndWritePythonCodeBlocks -InputString $text -StartDelimiter '```python' -EndDelimiter '```'; Assert ($out -match 'x = 1') 'fenced headings altered extraction' }
Case 'python-code-heading' { $text='4. Python code:' + "`n" + '```python' + "`nx = 1`n" + '```' + "`n5. Usage Example:`n" + '```python' + "`nprint(x)`n" + '```'; $out=Export-AndWritePythonCodeBlocks -InputString $text -StartDelimiter '```python' -EndDelimiter '```'; Assert ($out -match 'x = 1' -and $out -notmatch 'print') 'product prompt heading unsupported' }
Case 'load-failure' { Assert ($null -eq (Get-ProjectState (Join-Path $EvidenceRoot 'missing.xml'))) 'missing load accepted' }
Case 'final-encoding' { Assert ($source -match 'lastpydevCode \| Out-File -FilePath \$TheFinalCodeFullName -Encoding UTF8 -ErrorAction Stop') 'final encoding not explicit' }
$results | ConvertTo-Json -Depth 5 | Out-File (Join-Path $EvidenceRoot 'results.json') -Encoding utf8
$results | Format-Table -AutoSize
if (@($results | Where-Object {-not $_.pass}).Count) { exit 1 }
