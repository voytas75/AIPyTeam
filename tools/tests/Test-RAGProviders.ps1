param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
$source=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$t,[ref]$e)
$cases=New-Object Collections.Generic.List[object]
function Assert($name,$condition){if(-not $condition){throw "RAG contract failed: $name"};$cases.Add(@{name=$name;pass=$true})}
$names=@('Get-RAGSearchConfiguration','ConvertTo-RAGSearchResults','Invoke-SerpApiGoogleSearch','Invoke-SearchExa','Invoke-Serper','Invoke-RAGWebSearch')
foreach($name in $names){$fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);if($fn.Count -ne 1){throw "Missing RAG function: $name"};Invoke-Expression $fn[0].Extent.Text}
Assert 'parse' ($e.Count -eq 0)
foreach($name in 'SERPAPI_API_KEY','EXA_API_KEY','SERPER_API_KEY'){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
Assert 'no configuration' (@(Get-RAGSearchConfiguration).Count -eq 0)
$env:EXA_API_KEY='private-key-marker';Assert 'one provider enough' (@(Get-RAGSearchConfiguration).Count -eq 1)
$global:calls=New-Object Collections.Generic.List[object]
$global:mode='success'
function Invoke-RestMethod {param($Uri,$Method,$Headers,$Body,$ContentType,$TimeoutSec,$ErrorAction)
 $global:calls.Add(@{uri=$Uri;method=$Method;headers=$Headers;body=$Body;timeout=$TimeoutSec;contentType=$ContentType})
 if($global:mode -eq 'throw'){throw 'private-key-marker private-query-marker'}
 if($global:mode -eq 'empty'){return @{}}
 if($global:mode -eq 'fallback' -and $Uri -like '*serpapi*'){throw 'private-key-marker'}
 if($global:mode -eq 'fallback-empty' -and $Uri -like '*serpapi*'){return @{organic_results=@()}}
 if($global:mode -eq 'fallback-malformed' -and $Uri -like '*serpapi*'){return '{broken'}
 if($Uri -like '*serpapi*'){return @{organic_results=@(@{link='https://Example.invalid/Path'},@{link='https://Example.invalid/Path'},@{link='javascript:bad'},@{link='https://second.invalid/'})}}
 if($Uri -eq 'https://api.exa.ai/search'){return @{results=@(@{url='https://Example.invalid/Path'})}}
 if($Uri -eq 'https://google.serper.dev/search'){return '{"organic":[{"link":"https://Example.invalid/Path"}]}' }
 throw 'Unexpected offline transport'
}
$config=@(@{Provider='SerpApi';Key='private-key-marker'},@{Provider='EXA';Key='private-key-marker'},@{Provider='Serper';Key='private-key-marker'})
foreach($i in 0..2){$global:calls.Clear();$r=@(Invoke-RAGWebSearch -Query 'private-query-marker & unicode' -MaxCount 1 -Configuration @($config[$i]));Assert ('provider '+$i) ($r.Count -eq 1 -and $r[0].url -ceq 'https://Example.invalid/Path');Assert ('single request '+$i) ($global:calls.Count -eq 1 -and $global:calls[0].timeout -eq 10)
 $c=$global:calls[0]
 if($i -eq 0){Assert 'SerpApi GET encoding' ($c.method -eq 'GET' -and $c.uri -like '*engine=google*' -and $c.uri -like '*api_key=private-key-marker*' -and $c.uri -like '*num=1*' -and $c.uri -like '*%26*')}
 if($i -eq 1){$b=$c.body|ConvertFrom-Json;Assert 'EXA request contract' ($c.headers.Authorization -eq 'Bearer private-key-marker' -and $b.numResults -eq 1 -and $b.contents.text -eq $true -and $c.method -eq 'POST')}
 if($i -eq 2){$b=$c.body|ConvertFrom-Json;Assert 'Serper request contract' ($c.headers['X-API-KEY'] -eq 'private-key-marker' -and $b.num -eq 1 -and $b.q -eq 'private-query-marker & unicode')}
}
$global:calls.Clear();$r=@(Invoke-RAGWebSearch -Query q -MaxCount 2 -Configuration $config);Assert 'dedupe bounded and no fallthrough' ($r.Count -eq 2 -and $global:calls.Count -eq 1)
$global:mode='fallback';$global:calls.Clear();$r=@(Invoke-RAGWebSearch -Query q -Configuration $config);Assert 'exception fallback order' ($r.Count -eq 1 -and $global:calls.Count -eq 2 -and $global:calls[1].uri -eq 'https://api.exa.ai/search')
foreach($mode in 'fallback-empty','fallback-malformed'){$global:mode=$mode;$global:calls.Clear();$r=@(Invoke-RAGWebSearch -Query q -Configuration $config);Assert ($mode+' succeeds') ($r.Count -eq 1 -and $global:calls.Count -eq 2)}
foreach($mode in 'empty','throw'){$global:mode=$mode;$global:calls.Clear();$err='';try{Invoke-RAGWebSearch -Query q -Configuration $config|Out-Null}catch{$err=$_.Exception.Message};Assert ($mode+' all fail safe') ($err -eq 'RAG search failed: no configured provider returned usable HTTP results.' -and $global:calls.Count -eq 3)}
$global:calls.Clear();try{Invoke-RAGWebSearch -Query q -Configuration @()|Out-Null}catch{};Assert 'no keys zero HTTP' ($global:calls.Count -eq 0)
try{Invoke-RAGWebSearch -Query ' ' -Configuration $config|Out-Null}catch{};Assert 'empty query zero HTTP' ($global:calls.Count -eq 0)
$r=@(ConvertTo-RAGSearchResults -Response '{bad' -Provider Serper -MaxCount 2);Assert 'malformed JSON' ($r.Count -eq 0)
$r=@(ConvertTo-RAGSearchResults -Response @{organic=@(@{link='file:///x'},@{link='javascript:x'},@{link='https://host.invalid/Case'},@{link='https://host.invalid/case'})} -Provider Serper -MaxCount 2);Assert 'HTTP only case preservation' ($r.Count -eq 2 -and $r[0].url -cne $r[1].url)
foreach($provider in 'SerpApi','EXA','Serper'){
 $json=switch($provider){SerpApi{'{"organic_results":[{"link":"https://shape.invalid/"}]}'} EXA{'{"results":[{"url":"https://shape.invalid/"}]}'} Serper{'{"organic":[{"link":"https://shape.invalid/"}]}'} };
 foreach($shape in 'raw','object'){$response=if($shape -eq 'raw'){$json}else{$json|ConvertFrom-Json};$r=@(ConvertTo-RAGSearchResults -Provider $provider -Response $response);Assert ($provider+' '+$shape+' response') ($r.Count -eq 1 -and $r[0].url -eq 'https://shape.invalid/')}
}
$native=(Get-Process -Id $PID).Path
foreach($mode in 'fallback','allfail') {
 $out=Join-Path $EvidenceRoot ('entry-'+$mode);$args=@('-NOInteraction','-ReducedWorkflow','-ConfiguredRAG');if($mode -eq 'fallback'){$args+='-SearchFallback'}else{$args+='-SearchFailure'}
 & $native -NoProfile -NonInteractive -File (Join-Path $RepositoryRoot 'tools/tests/Test-ResponsesEntrypoint.ps1') -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @args *> (Join-Path $EvidenceRoot ($mode+'.log'))
 Assert ('original entry '+$mode) ($LASTEXITCODE -eq 0)
 $record=Get-Content (Join-Path $out entrypoint.json) -Raw|ConvertFrom-Json
 if($mode -eq 'fallback'){Assert 'entry fallback search page LLM counts' ($record.posts -eq 5 -and $record.gets -eq 2 -and $record.webs -eq 1 -and $record.UserEnvironmentUnchanged)}
 else{Assert 'entry allfail stops before cleaner and next agent' ($record.posts -eq 1 -and $record.gets -eq 1 -and $record.webs -eq 0 -and $record.outcome -eq 'Failed' -and $record.UserEnvironmentUnchanged)}
 $text=Get-Content (Join-Path $EvidenceRoot ($mode+'.log')) -Raw
 Assert ('entry sanitized '+$mode) (-not $text.Contains('private-search-transport-marker'))
}
# Normalize only the owned injected helper; product runs by original filepath.
foreach($mode in 'page-error','blank-page') {
 $out=Join-Path $EvidenceRoot ('entry-'+$mode)
 $helper=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/Test-ResponsesEntrypoint.ps1')).Replace("`r`n","`n")
 $pageAnchor='$global:webs++;return @{Content=''<p>Synthetic article</p>''}'
 if($mode -eq 'page-error'){$replacement='$global:webs++;throw ''private-page-error-marker synthetic-search synthetic-key''';if(-not $helper.Contains($pageAnchor)){throw 'Page injection anchor missing'};$helper=$helper.Replace($pageAnchor,$replacement)}
 else{$anchor='innerText="Synthetic article"';if(-not $helper.Contains($anchor)){throw 'Blank page injection anchor missing'};$helper=$helper.Replace($anchor,'innerText="   "')}
 foreach($anchor in @('elseif($SearchFailure)','($SearchFailure -or $FailAt -or $RejectDeveloper)','elseif($SearchFailure){1}')){if(-not $helper.Contains($anchor)){throw 'Failure expectation anchor missing'}}
 $helper=$helper.Replace('elseif($SearchFailure)','elseif($SearchFailure -or $ConfiguredRAG)').Replace('($SearchFailure -or $FailAt -or $RejectDeveloper)','($SearchFailure -or $ConfiguredRAG -or $FailAt -or $RejectDeveloper)')
 $fixture=Join-Path $EvidenceRoot ($mode+'-entry.ps1');[IO.File]::WriteAllText($fixture,$helper,(New-Object Text.UTF8Encoding($true)))
 $log=Join-Path $EvidenceRoot ($mode+'.log')
 & $native -NoProfile -NonInteractive -File $fixture -RepositoryRoot $RepositoryRoot -EvidenceRoot $out -NOInteraction -ReducedWorkflow -ConfiguredRAG *> $log
 Assert ('original entry '+$mode) ($LASTEXITCODE -eq 0)
 $record=Get-Content (Join-Path $out entrypoint.json) -Raw|ConvertFrom-Json
 $saved=Import-Clixml $record.project
 Assert ('entry '+$mode+' query only and persisted safe RAG failure') ($record.posts -eq 1 -and $record.gets -eq 1 -and $record.webs -eq 1 -and $record.reads -eq 0 -and $record.UserEnvironmentUnchanged -and $record.originalEntry -eq $source -and $saved.WorkflowOutcome -eq 'Failed' -and $saved.FailedStage -eq 'RAG' -and $saved.WorkflowErrorCode -eq 'StageFailed' -and -not $saved.LastpydevCode -and -not (Test-Path $record.final))
 $texts=(Get-ChildItem $out -File -Recurse | Where-Object {$_.Extension -in '.txt','.log','.xml' -and $_.Name -ne 'TRANSCRIPT.log'} | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
 $texts += [IO.File]::ReadAllText($log)
 Assert ('entry '+$mode+' artifacts sanitized') ($texts -notmatch 'private-page-error-marker|synthetic-search|synthetic-key')
}
# Successful initial RAG and draft, then page challenge during Analyst feedback.
foreach($display in 'normal','minimal') {
 $out=Join-Path $EvidenceRoot ('second-page-'+$display)
 $helper=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tools/tests/Test-ResponsesEntrypoint.ps1')).Replace("`r`n","`n")
 $anchor='$global:webs++;return @{Content=''<p>Synthetic article</p>''}'
 if(-not $helper.Contains($anchor)){throw 'Second page injection anchor missing'}
 $helper=$helper.Replace($anchor,'$global:webs++;if($global:webs -eq 2){throw ''<html>Just a moment Enable JavaScript challenge-platform PRIVATE_PAGE_TOKEN</html>''};return @{Content=''<p>Synthetic article</p>''}')
 $helper=$helper.Replace('if($PartialRecovery -or $ActualRecovery -or $LateRejected -or ($FailAt -gt 2))','if($ConfiguredRAG -or $PartialRecovery -or $ActualRecovery -or $LateRejected -or ($FailAt -gt 2))')
 $helper=$helper.Replace('elseif($ConfiguredRAG){5}','elseif($ConfiguredRAG){6}')
 $fixture=Join-Path $EvidenceRoot ('second-page-'+$display+'.ps1');[IO.File]::WriteAllText($fixture,$helper,(New-Object Text.UTF8Encoding($true)))
 $log=Join-Path $EvidenceRoot ('second-page-'+$display+'.log')
 $args=@('-ConfiguredRAG');if($display -eq 'minimal'){$args+='-MinimalOutput'}
 & $native -NoProfile -NonInteractive -File $fixture -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @args *> $log
 Assert ('second page original entry '+$display) ($LASTEXITCODE -eq 0)
 $record=Get-Content (Join-Path $out entrypoint.json) -Raw|ConvertFrom-Json
 $saved=Import-Clixml $record.project
 $draft=Join-Path $saved.TeamDiscussionDataFolder TheCode_v1.py
 Assert ('second page Partial draft preserved '+$display) ($record.posts -eq 6 -and $record.gets -eq 2 -and $record.webs -eq 2 -and $record.reads -eq 1 -and $record.UserEnvironmentUnchanged -and $record.originalEntry -eq $source -and $saved.WorkflowOutcome -eq 'Partial' -and $saved.FailedStage -eq 'Analyst/Developer' -and $saved.WorkflowErrorCode -eq 'StageFailed' -and $saved.FileVersion -eq 2 -and (Test-Path $draft) -and [IO.File]::ReadAllText($draft).Trim() -eq $saved.LastpydevCode.Trim() -and -not (Test-Path (Join-Path $saved.TeamDiscussionDataFolder TheCode_v2.py)))
 $text=[IO.File]::ReadAllText($log)
 Assert ('second page required notifications '+$display) ($text.Contains('-- Error: RAG page extraction failed.') -and $text.Contains('Workflow Partial; stopped at Analyst/Developer.') -and $text.Contains('-- Error details have been saved to the file:') -and (Test-Path (Join-Path $saved.TeamDiscussionDataFolder ERROR.txt)))
 $hasHelp=$text.Contains('-- Context:') -and $text.Contains('-- Suggestions:')
 Assert ('second page help policy '+$display) $(if($display -eq 'minimal'){-not $text.Contains('-- Context:') -and -not $text.Contains('-- Suggestions:')}else{$hasHelp})
 Assert ('second page safe owned output '+$display) ($text -notmatch 'PRIVATE_PAGE_TOKEN|<html>|challenge-platform' -and [IO.File]::ReadAllText((Join-Path $saved.TeamDiscussionDataFolder ERROR.txt)) -notmatch 'PRIVATE_PAGE_TOKEN|<html>|challenge-platform')
}
@{sourceHash=(Get-FileHash $source).Hash;parseErrors=$e.Count;cases=@($cases.ToArray());scope='Source-bound offline HTTP mocks; no live API calls'}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
Write-Host "RAG providers passed: $($cases.Count)"
