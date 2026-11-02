param([string]$SourcePath,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$env:PSAOAI_BANNER='0'
foreach($pair in @(@('KEY','synthetic-key'),@('ENDPOINT','https://fixture.invalid/'),@('CC_DEPLOYMENT','fixture'),@('APIVERSION','2024-10-21'))){[Environment]::SetEnvironmentVariable(('PSAOAI_API_AZURE_OPENAI_'+$pair[0]),$pair[1],'Process')}
function global:Find-Module {param($Name,$Repository) [pscustomobject]@{Version=[version]'0.7.0'}}
Import-Module PSAOAI -Force
$m=Get-Module PSAOAI
$before=@(Get-ChildItem $m.ModuleBase -File -Recurse|Sort-Object FullName|ForEach-Object {(Get-FileHash $_.FullName).Hash}) -join '|'
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
foreach($name in @('Invoke-LLMChatCompletion','Invoke-AIPyTeamAzureOpenAIChatCompletion')){ $f=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name; . ([scriptblock]::Create($f.Extent.Text)) }
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath)}
$GlobalState=[pscustomobject]@{VerbosePrompt=$false}
& $m {
 $script:captured=@();$script:received=$null
 function script:Invoke-WebRequest {param($Uri,$Method,$Headers,$Body,$TimeoutSec,$ErrorAction,$ContentType)
  $script:captured+=@{body=($Body|ConvertFrom-Json);timeout=$TimeoutSec;method=$Method;uri=$Uri;keySynthetic=($Headers['api-key'] -eq 'synthetic-key')}
  $json='{"choices":[{"finish_reason":"stop","message":{"content":"AZURE_OK"}}],"usage":{"completion_tokens":3}}'
  [pscustomobject]@{RawContentStream=(New-Object IO.MemoryStream(,[Text.Encoding]::UTF8.GetBytes($json)))}
 }
 function script:Start-Job {param($ScriptBlock,$ArgumentList) $script:received=& $ScriptBlock @ArgumentList; [pscustomobject]@{Id=1;JobStateInfo=[pscustomobject]@{State='Completed'}}}
 function script:Receive-Job {param($Id,[switch]$Wait,$ErrorAction) $script:received}
 function script:Remove-Job {param($Id,$Job,[switch]$Force)}
}
$rows=@()
foreach($mode in @('bounded','legacy-omitted')){
 $caught=$null;$reply=$null
 try {
  $args=@{Provider='AzureOpenAI';SystemPrompt='Reply literally AZURE_OK.';UserPrompt='AZURE_OK';Temperature=0;TopP=1;Stream=$false;LogFolder=$EvidenceRoot;DeploymentChat='fixture'}
  if($mode -eq 'bounded'){$args.MaxTokens=256;$args.TimeOut=60}
  $reply=Invoke-LLMChatCompletion @args
 }catch{$caught=$_.Exception.GetType().FullName}
 $requests=@(& $m {$script:captured});$last=$requests|Select-Object -Last 1
 $expectedTokens=if($mode -eq 'bounded'){256}else{4096};$expectedTimeout=if($mode -eq 'bounded'){60}else{240}
 $expectedCount=if($mode -eq 'bounded'){1}else{2}
 $pass=($requests.Count -eq $expectedCount -and $null -eq $caught -and $reply.Trim() -eq 'AZURE_OK' -and $last.body.max_tokens -eq $expectedTokens -and $last.timeout -eq $expectedTimeout -and $last.body.stream -eq $false -and $last.body.n -eq 1 -and $last.method -eq 'POST' -and $last.keySynthetic -and $last.uri -eq 'https://fixture.invalid/openai/deployments/fixture/chat/completions?api-version=2024-10-21' -and $last.body.messages[0].content -eq 'Reply literally AZURE_OK.' -and $last.body.messages[1].content.Trim() -eq 'AZURE_OK' -and $last.body.temperature -eq 0 -and $last.body.top_p -eq 1)
 $rows+=@{id=$mode;pass=$pass;errorType=$caught;requests=$requests.Count;request=$last}
}
# Local routing receives no new Azure-only options.
function Invoke-AIPyTeamLMStudioChatCompletion {param($SystemPrompt,$UserPrompt,$Temperature,$TopP,$Stream,$ApiKey,$endpoint,$Model) 'local'}
function Invoke-AIPyTeamOllamaCompletion {param($SystemPrompt,$UserPrompt,$Temperature,$TopP,$ollamaModel,$Stream) 'local'}
foreach($p in @('LMStudio','ollama')){ $r=Invoke-LLMChatCompletion -Provider $p -MaxTokens 256 -Stream $false -LogFolder $EvidenceRoot; $rows+=@{id=$p;pass=($r -eq 'local')} }
$after=@(Get-ChildItem $m.ModuleBase -File -Recurse|Sort-Object FullName|ForEach-Object {(Get-FileHash $_.FullName).Hash}) -join '|'
$receipt=@{runtime=$PSVersionTable.PSVersion.ToString();sourceHash=(Get-FileHash $SourcePath).Hash;modulePath=$m.Path;moduleFilesUnchanged=($before -eq $after);transport='real PSAOAI request scriptblock; Start-Job synchronous fixture and controlled Invoke-WebRequest';cases=$rows;parseErrors=$e.Count}
$receipt|ConvertTo-Json -Depth 20|Set-Content (Join-Path $EvidenceRoot 'receipt.json') -Encoding UTF8
$rows|ForEach-Object {Write-Output ($_.id+': '+$_.pass)}
if(@($rows|Where-Object {-not $_.pass}).Count -or $before -ne $after -or $e.Count){exit 1}
