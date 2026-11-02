param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
$source=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
$text=[IO.File]::ReadAllText($source)
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
$cases=New-Object Collections.Generic.List[object]
function Check($name,$ok) { $cases.Add(@{name=$name;pass=[bool]$ok}) }
Check 'native-parser' ($errors.Count -eq 0)
Check 'initial-manager-override' ($text -match '\$projectManager\.ProcessInput\(\$projectManagerPrompt,\s*\$initialManagerSystemPrompt\)')
Check 'shared-code-contract' ($text -match 'function Get-CodeResponseContract')
Check 'original-scope-builder' ($text -match 'function Get-OriginalTaskBlock')
Check 'static-QA' ($text -match 'Static review only; tests not executed' -and $text -match 'logger scope' -and $text -match 'API existence')
$activeText=$text.Substring($text.IndexOf('function Get-CodeResponseContract'))
Check 'no-active-tip-slogans' ($activeText -notmatch 'There is.*tip for this task|I will tip you')
Check 'no-menu-reasoning-slogans' ($text -notmatch 'Think step by step\. Make sure your answer is unbiased')
Check 'no-enterprise-imposition' ($text -notmatch 'large enterprise environment|future-proof architecture|free of bugs')
if($text -match 'function Get-OriginalTaskBlock') {
 foreach($name in 'Get-OriginalTaskBlock','Get-CodeResponseContract','Get-FeedbackPrompt') {
  $node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
  Invoke-Expression $node.Extent.Text
 }
 $state=[pscustomobject]@{OrgUserInput='ORIGINAL-$-{}-scope';UserInput='DERIVED';LastpydevCode='x = 1'}
 $block=Get-OriginalTaskBlock $state
 Check 'original-not-derived' ($block.Contains($state.OrgUserInput) -and -not $block.Contains('DERIVED'))
 $legacy=Get-OriginalTaskBlock ([pscustomobject]@{UserInput='LEGACY-SCOPE'})
 Check 'legacy-fallback' ($legacy.Contains('LEGACY-SCOPE'))
 $review=Get-FeedbackPrompt -description 'DERIVED' -code 'x = 1' -originalTask $state.OrgUserInput
 Check 'rendered-review-original' ($review.Contains($state.OrgUserInput) -and $review.Contains('Derived guidelines'))
 $contract=Get-CodeResponseContract
 Check 'rendered-exact-headings' ($contract.Contains('4. Python code') -and $contract.Contains('5. Usage Example') -and $contract.Contains('6. Self-Review Notes'))
} else {
 foreach($name in 'original-not-derived','legacy-fallback','rendered-review-original','rendered-exact-headings'){Check $name $false}
}
@{sourceHash=(Get-FileHash $source).Hash;parseErrors=$errors.Count;cases=@($cases.ToArray());scope='Source contract and native rendered builders; no model compliance evidence'} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $EvidenceRoot 'receipt.json') -Encoding UTF8
if(@($cases | Where-Object {-not $_.pass}).Count){exit 1}
