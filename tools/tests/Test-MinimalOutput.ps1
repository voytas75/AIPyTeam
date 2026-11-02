param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$base=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/Test-ResponsesEntrypoint.ps1')).Replace("`r`n","`n")
$native=(Get-Process -Id $PID).Path
$rows=@()
function Canonical($value) {
 if($null -eq $value){return 'null'}
 if($value -is [string] -or $value -is [ValueType]){return ($value|ConvertTo-Json -Compress)}
 if($value -is [array]){return ('['+((@($value|ForEach-Object {Canonical $_})) -join ',')+']')}
 return ('{'+((@($value.PSObject.Properties|Sort-Object Name|ForEach-Object {($_.Name|ConvertTo-Json -Compress)+':'+(Canonical $_.Value)})) -join ',')+'}')
}
function SameChain($left,$right) {
 if(@($left).Count -ne @($right).Count -or @($left).Count -eq 0){return $false}
 for($i=0;$i -lt @($left).Count;$i++){if((Canonical ($left[$i]|ConvertFrom-Json)) -cne (Canonical ($right[$i]|ConvertFrom-Json))){return $false}}
 return $true
}
foreach($mode in 'normal','reduced','full','interactive','menu-normal','menu-minimal','rag-normal','rag-minimal','resume','savefail','reject','stagefail') {
 $out=Join-Path $EvidenceRoot $mode;New-Item -ItemType Directory -Force $out|Out-Null
 $fixture=$base.Replace('x = 1','x = 1 # MODEL_PRIVATE_TEXT')
 if($mode -notin 'normal','menu-normal','rag-normal') {
  $fixture=$fixture.Replace('& $entry ', '& $entry -MinimalOutput ')
 }
 if($mode -like 'menu-*') {
  $fixture=$fixture.Replace(";'Q'}", ';$answer=@(''1'',''change'',''2'',''explain'',''3'',''question'',''4'',''5'',''7'',''Y'',''8'',''Y'',''Q'')[$global:reads-1];return $answer}')
  $fixture=$fixture.Replace('-UserInput ''Synthetic offline draft''', '-Verbose -VerbosePrompt -UserInput ''Synthetic offline draft''')
  $fixture=$fixture.Replace('elseif($RejectDeveloper -or $ReducedWorkflow){2}', 'elseif($RejectDeveloper){2}elseif($ReducedWorkflow){10}')
 }
 # Record original request content independently of display, with stable fixture replies.
 $fixture=$fixture.Replace('$b=$Body|ConvertFrom-Json', '$b=$Body|ConvertFrom-Json; $record=@{uri=$Uri;body=$b}; $record|ConvertTo-Json -Depth 30 -Compress|Add-Content (Join-Path $EvidenceRoot request-chain.jsonl) -Encoding UTF8')
 $fixture += @'

    if ($saved -and $saved.PSObject.Properties['MinimalOutput']){throw 'MinimalOutput persisted'}
'@
 $runner=Join-Path $out fixture.ps1;$fixture|Set-Content $runner -Encoding UTF8
 $args=@();if($mode -notin 'interactive','menu-normal','menu-minimal'){$args+='-NOInteraction'}
 if($mode -ne 'full'){$args+='-ReducedWorkflow'}
 if($mode -like 'rag-*'){$args+='-ConfiguredRAG'}
 if($mode -eq 'resume'){$args+='-Resume';$args+='-SavedReduced'}
 if($mode -eq 'savefail'){$args+='-FailedSave'}
 if($mode -eq 'reject'){$args+='-RejectDeveloper'}
 if($mode -eq 'stagefail'){$args+='-FailAt';$args+='1'}
 & $native -NoProfile -NonInteractive -File $runner -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @args *> (Join-Path $out stdout.log)
 $exit=$LASTEXITCODE;$text=Get-Content (Join-Path $out stdout.log) -Raw
 $ok=$exit -eq 0
 if($mode -in 'normal','menu-normal','rag-normal'){$ok=$ok -and $text.Contains('MODEL_PRIVATE_TEXT')}
 else {
  $ok=$ok -and -not $text.Contains('MODEL_PRIVATE_TEXT') -and $text.Contains('++ Ustawienia efektywne:') -and $text.Contains('++ Podane parametry:')
  if($mode -in 'reduced','full','interactive'){$logs=(Get-ChildItem $out -Filter '*.log' -Recurse|Where-Object {$_.Name -ne 'stdout.log'}|ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n";$ok=$ok -and $logs.Contains('MODEL_PRIVATE_TEXT') -and $text.Contains('++ Kod wygenerowany i zapisany:') -and $text.Contains('++ Stan projektu zapisany:')}
  if($mode -eq 'savefail'){$ok=$ok -and -not $text.Contains('++ Stan projektu zapisany:') -and $text.Contains('SaveProjectState')}
  if($mode -eq 'resume'){$ok=$ok -and $text.Contains('workflow=skrócony') -and $text.Contains('RAG=False') -and -not $text.Contains('Some values of the imported project:')}
  if($mode -eq 'interactive'){$ok=$ok -and $text.Contains('Please select an option')}
  if($mode -in 'reject','stagefail'){$ok=$ok -and -not $text.Contains('++ Kod wygenerowany i zapisany:') -and $text.Contains('++ Wynik workflow: Failed')}
 }
 $rows+=@{name=$mode;pass=[bool]$ok;exitCode=$exit}
}
foreach($pair in @(@('normal','reduced'),@('menu-normal','menu-minimal'),@('rag-normal','rag-minimal'))) {
 $left=Get-Content (Join-Path (Join-Path $EvidenceRoot $pair[0]) request-chain.jsonl)
 $right=Get-Content (Join-Path (Join-Path $EvidenceRoot $pair[1]) request-chain.jsonl)
 $rows+=@{name=('payload-identical-'+$pair[1]);pass=[bool]((SameChain $left $right) -and $left.Count -gt 0);exitCode=0}
}
$llama=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/Test-LlamaCpp.ps1')).Replace("`r`n","`n")
foreach($transport in 'json','stream') {
 foreach($display in 'normal','minimal') {
  $out=Join-Path $EvidenceRoot ('llama-'+$transport+'-'+$display);New-Item -ItemType Directory -Force $out|Out-Null
  $fixture=$llama.Replace('x = 1','x = 1 # MODEL_PRIVATE_TEXT')
  if($display -eq 'minimal'){$fixture=$fixture.Replace('& $source @args','& $source -MinimalOutput -Verbose -VerbosePrompt @args')}
  $fixture=$fixture.Replace('$b=$request.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json', '$b=$request.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json; $b|ConvertTo-Json -Depth 30 -Compress|Add-Content (Join-Path $EvidenceRoot request-chain.jsonl) -Encoding UTF8')
  $runner=Join-Path $out fixture.ps1;$fixture|Set-Content $runner -Encoding UTF8
  & $native -NoProfile -NonInteractive -File $runner -RepositoryRoot $RepositoryRoot -EvidenceRoot $out -EntryCase $transport *> (Join-Path $out stdout.log)
  $ok=$LASTEXITCODE -eq 0;$text=Get-Content (Join-Path $out stdout.log) -Raw
  if($display -eq 'minimal'){$ok=$ok -and -not $text.Contains('MODEL_PRIVATE_TEXT')}
  $rows+=@{name=('llama-'+$transport+'-'+$display);pass=[bool]$ok;exitCode=$LASTEXITCODE}
 }
 $left=Get-Content (Join-Path (Join-Path $EvidenceRoot ('llama-'+$transport+'-normal')) request-chain.jsonl)
 $right=Get-Content (Join-Path (Join-Path $EvidenceRoot ('llama-'+$transport+'-minimal')) request-chain.jsonl)
 $rows+=@{name=('llama-payload-identical-'+$transport);pass=[bool]((SameChain $left $right) -and $left.Count -eq 2);exitCode=0}
}
$entry=Join-Path $RepositoryRoot AIPyTeam.ps1
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$tokens,[ref]$errors)
foreach($name in 'Export-AndWritePythonCodeBlocks','Update-ErrorHandling') {
 $definition=$ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)|Select-Object -First 1
 Invoke-Expression $definition.Extent.Text
}
$script:MinimalOutput=$true;$GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot}
$target=Join-Path $EvidenceRoot locked.py;[IO.File]::WriteAllText($target,'sentinel')
$lock=[IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
 $capture=@(Export-AndWritePythonCodeBlocks -InputString ('```python'+"`nx = 1`n"+'```') -StartDelimiter '```python' -EndDelimiter '```' -OutputFilePath $target 6>&1)
 $result=@($capture|Where-Object {$_ -isnot [Management.Automation.InformationRecord]})
 $notice=($capture|Out-String)
 $ok=$result.Count -eq 1 -and $result[0] -eq $false -and -not $notice.Contains('++ Kod wygenerowany i zapisany:')
} finally {$lock.Dispose()}
$ok=$ok -and [IO.File]::ReadAllText($target) -eq 'sentinel'
$rows+=@{name='locked-export';pass=[bool]$ok;exitCode=0}

# Conflicting saved/CLI values through the original filepath in fresh children.
foreach($display in 'normal','minimal') {
 foreach($provider in 'azure','llama') {
  $out=Join-Path $EvidenceRoot ('recovery-'+$provider+'-'+$display);New-Item -ItemType Directory -Force $out|Out-Null
  if($provider -eq 'azure') {
   $fixture=$base.Replace('RAG=$false;Stream=$false','RAG=$true;Stream=$false')
   $fixture=$fixture.Replace('if($SavedReduced){$state|Add-Member ReducedWorkflow $true}', '$state|Add-Member ReducedWorkflow $false')
   $fixture=$fixture.Replace('$resumeArgs=@{}','$resumeArgs=@{NORAG=$true;Stream=$true;AzureResponsesTimeoutSec=19}')
   $fixture += "`nif(-not `$saved.RAG -or `$saved.ReducedWorkflow -or `$saved.Stream -or `$saved.AzureResponsesTimeoutSec -ne 60){throw 'Saved effective values lost'}"
   if($display -eq 'minimal'){$fixture=$fixture.Replace('& $entry ', '& $entry -MinimalOutput ')}
   $args=@('-Resume','-NOInteraction','-ReducedWorkflow')
  } else {
   $fixture=$llama.Replace('RAG=$false;Stream=$true;ReducedWorkflow=$true','RAG=$true;Stream=$true;ReducedWorkflow=$false')
   $fixture=$fixture.Replace("`$env:LLAMACPP_ENDPOINT='https://fixture.invalid/'","`$env:LLAMACPP_ENDPOINT='https://fixture.invalid/';`$env:AZURE_BING_API_KEY='synthetic-bing';`$env:AZURE_BING_SEARCH_ENDPOINT='https://bing.fixture.invalid/'")
   $fixture=$fixture.Replace("$"+'args.Stream=$false}',"$"+'args.Stream=$false;$args.NORAG=$true;$args.ReducedWorkflow=$true;$args.LlamaCppTimeoutSec=17}')
   $fixture += "`nif(-not `$saved.RAG -or `$saved.ReducedWorkflow -or `$saved.Stream -or `$saved.LlamaCppModel -cne 'model-A' -or `$saved.LlamaCppTimeoutSec -ne 17){throw 'Local override/effective values lost'}"
   if($display -eq 'minimal'){$fixture=$fixture.Replace('& $source @args','& $source -MinimalOutput @args')}
   $args=@('-EntryCase','resume-override')
  }
  $runner=Join-Path $out fixture.ps1;$fixture|Set-Content $runner -Encoding UTF8
  & $native -NoProfile -NonInteractive -File $runner -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @args *> (Join-Path $out stdout.log)
  $ok=$LASTEXITCODE -eq 0;$text=Get-Content (Join-Path $out stdout.log) -Raw
  if($display -eq 'minimal'){$ok=$ok -and $text.Contains('workflow=pełny; Stream=False; RAG=True')}
  $rows+=@{name=('recovery-'+$provider+'-'+$display);pass=[bool]$ok;exitCode=$LASTEXITCODE}
 }
}
# Public parameter inventory from the actual source AST; no raw explicit values.
$startup=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Show-AIPyTeamStartup'},$true)|Select-Object -First 1
Invoke-Expression $startup.Extent.Text
$explicit=@{};foreach($p in $ast.ParamBlock.Parameters){$explicit[$p.Name.VariablePath.UserPath]='PRIVATE_ARGUMENT_SENTINEL'}
$explicit.Verbose=$true;$explicit.Debug=$true
$state=[pscustomobject]@{LLMProvider='AzureOpenAI';AzureOpenAIProtocol='Responses';ReducedWorkflow=$false;Stream=$false;RAG=$true}
$capture=Show-AIPyTeamStartup $state $explicit 6>&1|Out-String
$ok=-not $capture.Contains('PRIVATE_ARGUMENT_SENTINEL')
foreach($name in $explicit.Keys){$ok=$ok -and $capture.Contains("++ -${name}:")}
$ok=$ok -and -not $capture.Contains('parametr wspólny')
$rows+=@{name='all-public-parameter-descriptions';pass=[bool]$ok;exitCode=0}
$minimalParam=$ast.ParamBlock.Parameters|Where-Object {$_.Name.VariablePath.UserPath -eq 'MinimalOutput'}
$ok=$minimalParam.StaticType -eq [Management.Automation.SwitchParameter] -and -not $minimalParam.DefaultValue
$rows+=@{name='minimal-default-false';pass=[bool]$ok;exitCode=0}
# Native binder rejects unknown flags before dependency/workflow execution.
$binding=Join-Path $EvidenceRoot binding.ps1
($ast.ParamBlock.Extent.Text+"`nthrow 'BINDER_DID_NOT_REJECT'")|Set-Content $binding -Encoding UTF8
$ErrorActionPreference='Continue'
& $native -NoProfile -NonInteractive -File $binding -UnknownMinimalArgument *> (Join-Path $EvidenceRoot binding.log)
$ErrorActionPreference='Stop'
$ok=$LASTEXITCODE -ne 0 -and -not (Get-Content (Join-Path $EvidenceRoot binding.log) -Raw).Contains('BINDER_DID_NOT_REJECT')
$rows+=@{name='unknown-native-binding-rejected';pass=[bool]$ok;exitCode=$LASTEXITCODE}
$global:LASTEXITCODE=0

@{sourceHash=(Get-FileHash (Join-Path $RepositoryRoot AIPyTeam.ps1)).Hash;cases=$rows;scope='Original entrypoint owned dependency/HTTP fixtures; stdout capture, not transcript privacy; no model calls'}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
if(@($rows|Where-Object {-not $_.pass}).Count){exit 1}
