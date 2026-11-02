param([string]$RepositoryRoot,[string]$EvidenceRoot,[string]$EntryCase)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$source=Join-Path $RepositoryRoot AIPyTeam.ps1
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Source parser failure'}
$functions=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -match '^(.*LlamaCpp.*|Get-ProjectState)$'},$true)
$rows=@()
function Check($name,[scriptblock]$action){try{& $action;$script:rows+=@{name=$name;pass=$true}}catch{$script:rows+=@{name=$name;pass=$false;error=$_.Exception.Message}}}
function Assert($ok,$message){if(-not $ok){throw $message}}
if(-not $EntryCase){
 foreach($f in $functions){. ([scriptblock]::Create($f.Extent.Text))}
 Check 'literal-provider' {Assert ($ast.ParamBlock.Extent.Text -match '"llama.cpp"') 'Missing dedicated provider'}
 Check 'request-root-auth-budget' {$r=New-AIPyTeamLlamaCppRequest -Endpoint 'https://fixture.invalid/' -Model 'model-B' -ApiKey 'synthetic' -MaxTokens 37 -Stream $true -TimeOut 19;$b=$r.Body|ConvertFrom-Json;Assert ($r.Uri -eq 'https://fixture.invalid/v1/chat/completions' -and $r.Headers.Authorization -eq 'Bearer synthetic' -and $b.model -ceq 'model-B' -and $b.max_tokens -eq 37 -and $b.stream -and $r.TimeoutSec -eq 19) 'Request mismatch'}
 Check 'request-v1-noauth' {$r=New-AIPyTeamLlamaCppRequest -Endpoint 'https://fixture.invalid/v1/' -Model 'model-A';Assert ($r.Uri -eq 'https://fixture.invalid/v1/chat/completions' -and -not $r.Headers.Authorization) 'Normalization/auth mismatch'}
 foreach($v in '','   '){Check ('blank-model-'+$v.Length) {$caught=$false;try{New-AIPyTeamLlamaCppRequest -Endpoint 'https://fixture.invalid' -Model $v}catch{$caught=$true};Assert $caught 'Blank model admitted'}}
 Check 'endpoint-invalid' {$caught=$false;try{Resolve-AIPyTeamLlamaCppEndpoint 'file:///bad'}catch{$caught=$true};Assert $caught 'Invalid endpoint admitted'}
 Check 'sse-deltas-done' {Assert ((ConvertFrom-AIPyTeamLlamaCppSSE "data: {`"choices`": [{`"delta`": {`"content`": `"hello`"}}]}`n`ndata: {`"choices`": [{`"delta`": {`"content`": `" world`"}}]}`n`ndata: [DONE]`n") -eq 'hello world') 'SSE mismatch'}
 foreach($text in @('data: {bad}', 'data: {"choices":[{"delta":{"content":"x"}}]}', ('data: {"error":{"message":"synthetic"}}'+"`ndata: [DONE]"), ('data: {"choices":[{"delta":{"content":42}}]}'+"`ndata: [DONE]"), 'data: [DONE]')){Check ('sse-reject-'+$rows.Count) {$caught=$false;try{ConvertFrom-AIPyTeamLlamaCppSSE $text}catch{$caught=$true};Assert $caught 'Malformed/empty stream admitted'}}
 Check 'json-valid' {Assert ((ConvertFrom-AIPyTeamLlamaCppResponse @{choices=@(@{message=@{content='hello'}})}) -eq 'hello') 'JSON mismatch'}
 foreach($result in @(@{choices=@()},@{choices=@(@{message=@{content=' '}})},@{choices=@(@{message=@{content=42}})},@{error=@{message='synthetic'}})){Check ('json-reject-'+$rows.Count) {$caught=$false;try{ConvertFrom-AIPyTeamLlamaCppResponse $result}catch{$caught=$true};Assert $caught 'Invalid JSON admitted'}}
 $native=(Get-Process -Id $PID).Path
 foreach($case in 'stream','json','full','key','first','resume','resume-override','missing-endpoint','invalid-model','empty-models','auth-failed','manager-failed','developer-failed','developer-empty','developer-rejected','stream-malformed','stream-incomplete','stream-http-failed','blank-model','invalid-model-shape','resume-blank','resume-timeout'){
  $out=Join-Path $EvidenceRoot $case
  $ErrorActionPreference='Continue'
  & $native -NoProfile -NonInteractive -File $PSCommandPath -RepositoryRoot $RepositoryRoot -EvidenceRoot $out -EntryCase $case *> (Join-Path $EvidenceRoot ($case+'.log'))
  $ok=$LASTEXITCODE -eq 0
  if($ok){$ok=(Get-Content (Join-Path $out entrypoint.json) -Raw|ConvertFrom-Json).pass -eq $true}
  $rows+=@{name=('entry-'+$case);pass=$ok;exitCode=$LASTEXITCODE}
 }
 @{sourceHash=(Get-FileHash $source).Hash;cases=$rows}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
 if(@($rows|Where-Object {-not $_.pass}).Count){exit 1};exit 0
}
# Original filepath execution; no product adapter extraction in this child.
$modules=Join-Path $EvidenceRoot modules
foreach($name in 'PSAOAI','PowerHTML'){$dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null;"@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}"|Set-Content (Join-Path $dir "$name.psd1") -Encoding UTF8;''|Set-Content (Join-Path $dir "$name.psm1") -Encoding UTF8}
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
$env:LLAMACPP_ENDPOINT='https://fixture.invalid/'
$env:LLAMACPP_API_KEY=if($EntryCase -eq 'key'){'synthetic'}else{''}
$global:posts=0;$global:gets=0;$global:reads=0
function global:Read-Host {$global:reads++;throw 'Input forbidden'}
function global:Find-Script {@{Version='0.0.3'}}
function global:Invoke-WebRequest {throw 'Unexpected transport'}
function global:Invoke-RestMethod {param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction,$ContentType)
 if($Method -eq 'GET'){
  $global:gets++;Assert ($Uri -eq 'https://fixture.invalid/v1/models') 'Discovery URI';Assert ($TimeoutSec -eq 17) 'Discovery timeout'
  Assert ($Headers.Authorization -eq $(if($EntryCase -eq 'key'){'Bearer synthetic'}else{$null})) 'Discovery auth'
  if($EntryCase -eq 'auth-failed'){throw 'Synthetic auth failure'}
  if($EntryCase -eq 'empty-models'){return @{data=@()}}
  if($EntryCase -eq 'invalid-model-shape'){return @{data=@(@{id=42})}}
  return @{data=@(@{id='model-A'},@{id='model-B'})}
 }
 throw 'Unexpected REST completion: llama.cpp must use owned HttpClient transport'
}
Add-Type -AssemblyName System.Net.Http
Add-Type -ReferencedAssemblies @('System.Net.Http') -TypeDefinition @'
using System;using System.Net;using System.Net.Http;using System.Threading;using System.Threading.Tasks;
public class LlamaFixtureHandler:HttpMessageHandler {
 public static int Posts;public static Func<HttpRequestMessage,HttpResponseMessage> Respond;
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken c){Posts++;return Task.FromResult(Respond(r));}
}
'@
[LlamaFixtureHandler]::Respond={param($request)
 $global:posts++
 Assert ($request.RequestUri.AbsoluteUri -eq 'https://fixture.invalid/v1/chat/completions') 'POST URI'
 $b=$request.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json
 $model=if($EntryCase -eq 'first'){'model-A'}else{'model-B'}
 Assert ($b.model -ceq $model -and $b.max_tokens -eq 256 -and $b.messages.Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($b.messages[0].content)) 'Payload/model/budget'
 Assert ([string]$request.Headers.Authorization -eq $(if($EntryCase -eq 'key'){'Bearer synthetic'}else{''})) 'POST auth'
 $text="4. Python code:`n"+'```python'+"`nx = 1`n"+'```'+"`n5. Usage Example:"
 if($EntryCase -eq 'developer-empty' -and $global:posts -eq 2){$text=' '}
 if($EntryCase -eq 'developer-rejected' -and $global:posts -eq 2){$text='No code available'}
 $status=200
 if(($EntryCase -eq 'manager-failed' -and $global:posts -eq 1) -or ($EntryCase -eq 'developer-failed' -and $global:posts -eq 2) -or $EntryCase -eq 'stream-http-failed'){$status=401}
 if($b.stream){$content='data: '+(@{choices=@(@{delta=@{content=$text}})}|ConvertTo-Json -Depth 6 -Compress)+"`n`ndata: [DONE]`n";if($EntryCase -eq 'stream-malformed'){$content="data: {broken}`n`ndata: [DONE]"};if($EntryCase -eq 'stream-incomplete'){$content=$content.Replace('data: [DONE]','')}}else{$content=@{choices=@(@{message=@{content=$text}})}|ConvertTo-Json -Depth 6 -Compress}
 $r=[Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]$status);$r.Content=[Net.Http.StringContent]::new($content);return $r
}
function global:New-AIPyTeamLlamaCppHttpClient {return [Net.Http.HttpClient]::new([LlamaFixtureHandler]::new())}
function UserHash {$e=[Environment]::GetEnvironmentVariables('User');$t=(@($e.Keys|Sort-Object -CaseSensitive)|ForEach-Object {"$_=$($e[$_])"}) -join "`n";$s=[Security.Cryptography.SHA256]::Create();[BitConverter]::ToString($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)))}
$before=UserHash
$args=@{UserInput='Synthetic offline draft';LLMProvider='llama.cpp';NOInteraction=$true;NORAG=$true;ReducedWorkflow=$true;LlamaCppModel='model-B';LlamaCppTimeoutSec=17;MaxTokens=256;DeploymentChat='unused';NOTips=$true;LogFolder=$EvidenceRoot}
if($EntryCase -eq 'json'){$args.Stream=$false}
if($EntryCase -eq 'first'){$args.Remove('LlamaCppModel')}
if($EntryCase -eq 'full'){$args.Remove('ReducedWorkflow');$args.NOPM=$true;$args.NODocumentator=$true}
if($EntryCase -eq 'invalid-model'){$args.LlamaCppModel='missing'}
if($EntryCase -eq 'blank-model'){$args.LlamaCppModel=' '}
if($EntryCase -eq 'missing-endpoint'){$env:LLAMACPP_ENDPOINT=''}
if($EntryCase -match '^resume'){
 $folder=Join-Path $EvidenceRoot project;New-Item -ItemType Directory -Force $folder|Out-Null
 $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$EvidenceRoot;MaxTokens=256;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$true;ReducedWorkflow=$true;LLMProvider='llama.cpp';LlamaCppModel='model-B';LlamaCppTimeoutSec=17;WorkflowOutcome='Partial';FailedStage='Analyst/Developer';WorkflowErrorCode='StageFailed'}
 if($EntryCase -eq 'resume-blank'){$state.LlamaCppModel=' '}
 if($EntryCase -eq 'resume-timeout'){$state.LlamaCppTimeoutSec=0}
 $xml=Join-Path $folder Project.xml;$state|Export-Clixml $xml
 $args=@{LoadProjectStatus=$xml;DeploymentChat='unused';NOInteraction=$true}
 if($EntryCase -eq 'resume-override'){$args.LlamaCppModel='model-A';$args.Stream=$false}
}
$caught=$false
try{& $source @args}catch{$caught=$true;$message=$_.Exception.Message}
$startupFailure=$EntryCase -in @('missing-endpoint','invalid-model','empty-models','auth-failed','blank-model','invalid-model-shape','resume-blank','resume-timeout')
if($startupFailure){Assert ($caught -and $global:posts -eq 0) 'Startup must fail before POST'}else{
 Assert (-not $caught) "Unexpected entry throw: $message"
 $projects=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse);Assert ($projects.Count -eq 1) 'Missing saved project';$saved=Import-Clixml $projects[0].FullName
 $resume=$EntryCase -match '^resume';$failed=$EntryCase -match 'failed|empty|rejected|malformed|incomplete'
 $expected=if($resume){0}elseif($EntryCase -eq 'full'){10}elseif($EntryCase -match '^manager|^stream-(malformed|incomplete|http-failed)'){1}else{2}
 Assert ($global:posts -eq $expected) 'Fail-stop/count mismatch'
 $outcome=if($resume){'Partial'}elseif($failed){'Failed'}else{'Completed'}
 Assert ($saved.WorkflowOutcome -eq $outcome -and $saved.LLMProvider -eq 'llama.cpp' -and $saved.LlamaCppTimeoutSec -eq 17) 'Saved outcome/provider/timeout'
 $model=if($EntryCase -in @('first','resume-override')){'model-A'}else{'model-B'};Assert ($saved.LlamaCppModel -ceq $model) 'Saved model'
 Assert ($saved.Stream -eq ($EntryCase -notin @('json','resume-override'))) 'Stream persistence'
 Assert (-not $saved.PSObject.Properties['LlamaCppApiKey'] -and -not $saved.PSObject.Properties['LlamaCppEndpoint']) 'Secret/endpoint persisted'
 if(-not $failed -and -not $resume){$final=Join-Path $saved.TeamDiscussionDataFolder TheCodeF.py;Assert ((Get-Content $final -Raw) -match '(?m)^x = 1') 'Actual export missing'}
}
Assert ($global:reads -eq 0 -and (UserHash) -eq $before) 'Input/User environment changed'
Assert ($global:gets -eq $(if($EntryCase -in @('missing-endpoint','blank-model','resume-blank','resume-timeout')){0}else{1})) 'Discovery count'
@{pass=$true;gets=$global:gets;posts=$global:posts;reads=$global:reads;sourceHash=(Get-FileHash $source).Hash;case=$EntryCase;originalEntry=$source;transport='in-memory HttpMessageHandler';UserEnvironmentUnchanged=$true}|ConvertTo-Json|Set-Content (Join-Path $EvidenceRoot entrypoint.json)
