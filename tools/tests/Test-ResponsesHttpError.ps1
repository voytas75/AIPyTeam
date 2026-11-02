param([string]$SourcePath,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
foreach($f in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object {$_.Name -in @('Get-AIPyTeamResponsesHttpError','New-AIPyTeamResponsesRequest','Invoke-AIPyTeamAzureResponses','Read-AIPyTeamResponsesResponse','Invoke-LLMChatCompletion')}){. ([scriptblock]::Create($f.Extent.Text))}
Add-Type @'
using System; using System.Net; using System.IO; using System.Text;
public class FixtureErrorResponse : WebResponse {
 public HttpStatusCode StatusCode { get { return HttpStatusCode.BadRequest; } }
 private string body; public FixtureErrorResponse(string value) { body=value; }
 public override Stream GetResponseStream() { return new MemoryStream(Encoding.UTF8.GetBytes(body)); }
}
'@
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-private-key'
$GlobalState=[pscustomobject]@{VerbosePrompt=$false}
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath)}
$script:posts=0
function Invoke-RestMethod {param($Uri,$Method,$Headers,$Body,$TimeoutSec,$ContentType,$ErrorAction)
 $script:posts++
 if($ContentType -ne 'application/json; charset=utf-8'){throw 'UTF8 content type missing'}
 $ex=[Net.WebException]::new('raw secret synthetic-private-key', $null,[Net.WebExceptionStatus]::ProtocolError,[FixtureErrorResponse]::new($script:body))
 $er=[Management.Automation.ErrorRecord]::new($ex,'Fixture400',[Management.Automation.ErrorCategory]::InvalidOperation,$null)
 if($script:details){$er.ErrorDetails=[Management.Automation.ErrorDetails]::new($script:body)}
 throw $er
}
$rows=@()
foreach($case in 'stream-json','details-json','nonjson','hostile-fields'){
 $script:details=$case -eq 'details-json'
 $script:body='{"error":{"code":"unsupported_parameter","param":"max_tokens","message":"synthetic-private-key https://private.invalid/?sig=secret Bearer arbitrary-token"}}'
 if($case -eq 'nonjson'){$script:body='<html>synthetic-private-key</html>'}
 if($case -eq 'hostile-fields'){$script:body='{"error":{"code":"https://private.invalid/secret","param":"Bearer secret","message":"private"}}'}
 $caught=$false;$msg=''
 try{Invoke-LLMChatCompletion -Provider AzureOpenAI -AzureOpenAIProtocol Responses -DeploymentChat model -MaxTokens 256 -TimeOut 60 -Stream $false -LogFolder $EvidenceRoot|Out-Null}catch{$caught=$true;$msg=$_.Exception.Message}
 $m=$script:LastAzureResponsesMetadata
 $safe=($m|ConvertTo-Json -Compress)+$msg
 $ok=$caught -and $m.status -eq 'transport_error' -and $m.httpStatus -eq 400 -and $m.errorMessage.Length -le 240 -and $safe -notmatch 'synthetic-private-key|private.invalid|arbitrary-token|Bearer|<html>'
 if($case -in @('stream-json','details-json')){$ok=$ok -and $m.errorCode -eq 'unsupported_parameter' -and $m.errorParam -eq 'max_tokens' -and $msg -match 'unsupported_parameter'}else{$ok=$ok -and -not $m.errorCode -and -not $m.errorParam}
 $rows+=@{id=$case;pass=[bool]$ok;metadata=$m}
}
@{runtime=$PSVersionTable.PSVersion.ToString();sourceHash=(Get-FileHash $SourcePath).Hash;parseErrors=$e.Count;posts=$script:posts;cases=$rows}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
if($e.Count -or $script:posts -ne 4 -or @($rows|Where-Object {-not $_.pass}).Count){exit 1}
