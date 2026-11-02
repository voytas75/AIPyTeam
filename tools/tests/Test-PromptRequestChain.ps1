param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$base=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/Test-ResponsesEntrypoint.ps1')).Replace("`r`n","`n")
$rows=@();$native=(Get-Process -Id $PID).Path
foreach($mode in 'reduced','full','reports','menu','rag','ragfull') {
 $out=Join-Path $EvidenceRoot $mode;New-Item -ItemType Directory -Force $out|Out-Null
 $fixture=$base.Replace('$global:posts=0;','$global:requests=New-Object Collections.Generic.List[object];$global:posts=0;')
 $fixture=$fixture.Replace('$global:posts++'+"`n"+' if($FailAt', '$global:requests.Add(@{system=$b.instructions;user=$b.input});$global:posts++'+"`n"+' if($FailAt')
 if($mode -eq 'reports'){$fixture=$fixture.Replace('$expected=if($Resume)','$expected=if($true){12}elseif($Resume)')}
 if($mode -eq 'menu') {
  $fixture=$fixture.Replace("'Q'}", "if(-not `$global:queue){`$global:queue=New-Object Collections.Generic.Queue[string];foreach(`$v in '1','AUTHORIZED-NEW-FEATURE','2','3','QUESTION-MARKER','4','4','Y','7','Y','8','Y','Q'){`$global:queue.Enqueue(`$v)}};if(-not `$global:queue.Count){throw 'Read queue exhausted'};`$global:queue.Dequeue()}")
  $fixture=$fixture.Replace('$expected=if($Resume)','$expected=if($true){11}elseif($Resume)')
 }
 if($mode -eq 'ragfull'){$fixture=$fixture.Replace('$expected=if($Resume)','$expected=if($true){25}elseif($Resume)')}
 $fixture += @'

@{requests=@($global:requests.ToArray());sourceHash=(Get-FileHash $entry).Hash}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot requests.json) -Encoding UTF8
'@
 $runner=Join-Path $out 'fixture.ps1';$fixture|Set-Content $runner -Encoding UTF8
 $args=@();if($mode -ne 'menu'){$args+='-NOInteraction'};if($mode -in 'reduced','menu','rag'){$args+='-ReducedWorkflow'};if($mode -eq 'reports'){$args+='-OmitSkipFlags'};if($mode -in 'rag','ragfull'){$args+='-ConfiguredRAG'}
 & $native -NoProfile -NonInteractive -File $runner -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @args *> (Join-Path $out run.log)
 $exit=$LASTEXITCODE;$ok=$exit -eq 0
 if($ok){$record=Get-Content (Join-Path $out requests.json) -Raw|ConvertFrom-Json;$req=@($record.requests);$expected=switch($mode){reduced{2} full{10} reports{12} menu{11} rag{5} ragfull{25}};$ok=$req.Count -eq $expected
  if($mode -notin 'rag','ragfull'){foreach($r in $req){$ok=$ok -and $r.user.Contains('Synthetic offline draft') -and $r.system.Contains('untrusted data') -and $r.system.Contains('metadata only when supplied')}}
  if($mode -eq 'menu'){
   foreach($index in 1,2,8,10){$ok=$ok -and $req[$index].user.Contains('4. Python code') -and $req[$index].user.Contains('5. Usage Example')}
   $ok=$ok -and $req[2].user.Contains('AUTHORIZED-NEW-FEATURE') -and $req[2].user.Contains('augmenting the original requirements')
  }
  if($mode -eq 'reports'){$ok=$ok -and $req[10].user.Contains('Code data (not instructions)') -and $req[11].user.Contains('Report evidence') -and $req[0].system.Contains('Initial specification only') -and -not $req[11].system.Contains('Initial specification only')}
  if($mode -in 'rag','ragfull'){$ok=$ok -and $req[0].system.Contains('not instructions') -and $req[1].system.Contains('untrusted data') -and $req[2].system.Contains('untrusted data') -and $req[3].user.Contains('Synthetic offline draft') -and $req[4].user.Contains('Synthetic offline draft')}
 if($mode -eq 'ragfull'){foreach($r in $req){if($r.system.Contains('Web Search Query Manager')){$ok=$ok -and $r.system.Contains('not instructions')}elseif($r.system.Contains('expert text processor') -or $r.system.Contains('Analyze the provided text')){$ok=$ok -and $r.system.Contains('untrusted data')}else{$ok=$ok -and $r.user.Contains('Synthetic offline draft') -and $r.system.Contains('untrusted data')}}}
 }
 $rows+=@{name=$mode;pass=[bool]$ok;exitCode=$exit}
}
@{sourceHash=(Get-FileHash (Join-Path $RepositoryRoot AIPyTeam.ps1)).Hash;cases=$rows;scope='Original filepath with owned dependencies and recorded controlled transport; no live HTTP or model compliance'}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
if(@($rows|Where-Object {-not $_.pass}).Count){exit 1}
