param([string]$RepositoryRoot,[string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
$s=Get-Content $entry -Raw
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$t,[ref]$e)
if($e.Count){throw 'Source parse errors'}
# Original parameter binding and complete startup execute by owned filepath, not scriptblock.
$prefix=$ast.ParamBlock.Extent.Text
$functions=($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)|Where-Object {$_.Extent.Text -match '^function\s'}|ForEach-Object {$_.Extent.Text}) -join "`n"
$start=$s.IndexOf('#region Setting Up');$end=$s.IndexOf('#region ollama',$start)
$guard=@'
function Test-ModuleMinVersion {param($ModuleName,$MinimumVersion) $true}
function Import-Module {param($Name,[switch]$Force)}
function Show-Banner {}
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath) throw $ErrorRecord}
'@
$probe=Join-Path $EvidenceRoot 'original-startup.ps1'
[IO.File]::WriteAllText($probe,('[CmdletBinding()]'+"`n"+$prefix+"`n"+$functions+"`n"+$guard+"`n"+$s.Substring($start,$end-$start)+"`n"+'return $GlobalState'))
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-key'
$rows=@()
$cases=@(
 @{id='omitted-provider-protocol-stream';args=@{};protocol='Responses';stream=$false},
 @{id='explicit-azure';args=@{LLMProvider='AzureOpenAI'};protocol='Responses';stream=$false},
 @{id='explicit-chat';args=@{AzureOpenAIProtocol='ChatCompletions'};protocol='ChatCompletions';stream=$true},
 @{id='explicit-responses';args=@{AzureOpenAIProtocol='Responses'};protocol='Responses';stream=$false},
 @{id='explicit-stream-rejected';args=@{AzureOpenAIProtocol='Responses';Stream=$true};reject=$true},
 @{id='local-lmstudio';args=@{LLMProvider='LMStudio'};protocol='Responses';stream=$true},
 @{id='local-ollama';args=@{LLMProvider='ollama';AzureOpenAIProtocol='Responses'};protocol='Responses';stream=$true},
 @{id='saved-chat';saved='ChatCompletions';savedStream=$true;args=@{};protocol='ChatCompletions';stream=$true},
 @{id='saved-responses';saved='Responses';savedStream=$false;args=@{AzureOpenAIProtocol='ChatCompletions';Stream=$true};protocol='Responses';stream=$false},
 @{id='saved-responses-stream-rejected';saved='Responses';savedStream=$true;args=@{Stream=$false};reject=$true},
 @{id='legacy-default-chat';saved='legacy';savedStream=$true;args=@{};protocol='ChatCompletions';stream=$true},
 @{id='legacy-explicit-responses-rejected';saved='legacy';savedStream=$true;args=@{AzureOpenAIProtocol='Responses'};reject=$true}
)
foreach($case in $cases){
 $folder=Join-Path $EvidenceRoot $case.id;New-Item -ItemType Directory -Force $folder|Out-Null
 $a=@{DeploymentChat='opaque-alias';UserInput='synthetic';LogFolder=$folder}
 foreach($key in $case.args.Keys){$a[$key]=$case.args[$key]}
 if($case.saved){
  $state=[pscustomobject]@{TeamDiscussionDataFolder=$folder;GlobalResponse=@();FileVersion=1;LastpydevCode='x = 1';GlobalpydevResponse=@();OrgUserInput='synthetic';UserInput='synthetic';LogFolder=$folder;MaxTokens=20480;VerbosePrompt=$false;NOTips=$true;NOLog=$false;NODocumentator=$true;NOPM=$true;RAG=$false;Stream=$case.savedStream;LLMProvider='AzureOpenAI';AzureResponsesTimeoutSec=60}
  if($case.saved -ne 'legacy'){$state|Add-Member AzureOpenAIProtocol $case.saved}
  $xml=Join-Path $folder Project.xml;$state|Export-Clixml $xml;$a.LoadProjectStatus=$xml
 }
 $caught=$null;$result=$null
 try{$result=& $probe @a}catch{$caught=$_.Exception.Message}
 $pass=if($case.reject){$caught -match 'streaming is unsupported'}else{(-not $caught) -and $result.AzureOpenAIProtocol -eq $case.protocol -and $result.Stream -eq $case.stream -and $result.MaxTokens -eq 20480 -and $result.AzureResponsesTimeoutSec -eq 60}
 $rows+=@{id=$case.id;pass=[bool]$pass;error=$caught;protocol=$result.AzureOpenAIProtocol;stream=$result.Stream}
}
@{sourceHash=(Get-FileHash $entry).Hash;runtime=$PSVersionTable.PSVersion.ToString();cases=$rows;scope='original params/functions/startup by filepath; guarded dependency import; no workflow or HTTP'}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
if(@($rows|Where-Object {-not $_.pass}).Count){exit 1}
