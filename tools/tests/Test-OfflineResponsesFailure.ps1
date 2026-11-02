param([string]$RepositoryRoot,[string]$EvidenceRoot,[switch]$Resume,[ValidateSet(1,2,4)][int]$FailAt=4,[string]$ProjectPath)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$modules=Join-Path $EvidenceRoot 'modules'
foreach($name in 'PSAOAI','PowerHTML'){$dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null;"@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}"|Out-File (Join-Path $dir "$name.psd1") -Encoding utf8;''|Out-File (Join-Path $dir "$name.psm1") -Encoding utf8}
$env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-key'
$global:posts=0
$global:denied=0
function global:Find-Script {param($Name,$ErrorAction) @{Version='0.0.3'}}
function global:Read-Host {param($Prompt) 'Q'}
function global:Invoke-WebRequest {throw 'Unexpected transport'}
function global:Invoke-RestMethod {param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction,$ContentType)
 if($Resume){$global:denied++;throw 'Recovery transport forbidden'}
 if($Uri -ne 'https://fixture.invalid/openai/v1/responses' -or $Method -ne 'POST' -or $Headers['api-key'] -ne 'synthetic-key'){throw 'Unexpected Responses transport'}
 $b=$Body|ConvertFrom-Json
 if($b.max_output_tokens -ne 10240 -or $TimeoutSec -ne 60 -or $b.store -ne $false -or $b.stream -ne $false -or $b.model -ne 'opaque-alias'){throw 'Budget/payload mismatch'}
 if($global:posts -ge $FailAt){$global:denied++;throw 'SAFE_DISPATCH_BLOCKED'}
 $global:posts++
 $Body|Set-Content (Join-Path $EvidenceRoot ('body-{0}.json' -f $global:posts)) -Encoding UTF8
 if($global:posts -eq $FailAt){throw 'Synthetic fourth HTTP400; not an actual provider error'}
 $text=Get-Content (Join-Path $RepositoryRoot 'tools/tests/fixtures/developer-full120-response10.txt') -Raw
 @{status='completed';output=@(@{type='message';role='assistant';content=@(@{type='output_text';text=$text})})}

}
$before=[Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress
$entry=Join-Path $RepositoryRoot 'AIPyTeam.ps1'
if($Resume){
 if(-not $ProjectPath){throw 'Resume requires original ProjectPath'}
 & $entry -LoadProjectStatus $ProjectPath -DeploymentChat opaque-alias
}else{
try { & $entry -UserInput 'Create a tiny self-contained Python standard-library script. Define greet(name) returning Hello, name! and a main() CLI using argparse. No external dependencies, no extra files, no networking. Keep code and analysis concise. Put all actual code in section 4 Python code; put command examples only in section 5 Usage Example.' -LLMProvider AzureOpenAI -AzureOpenAIProtocol Responses -AzureResponsesTimeoutSec 60 -MaxTokens 10240 -DeploymentChat opaque-alias -Stream $false -NORAG -NOPM -NODocumentator -NOTips -LogFolder $EvidenceRoot } catch {}
}
@{posts=$global:posts;blocked=$global:denied;completed=$false;UserEnvironmentUnchanged=($before -eq ([Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress));sourceHash=(Get-FileHash $entry).Hash}|ConvertTo-Json|Set-Content (Join-Path $EvidenceRoot replay.json) -Encoding UTF8
if(($Resume -and $global:posts -ne 0) -or (-not $Resume -and $global:posts -ne $FailAt) -or $global:denied -ne 0 -or $before -ne ([Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress)){exit 1}
$projects=if($Resume){@(Get-Item $ProjectPath)}else{@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)}
if($projects.Count -ne 1){throw 'Partial persisted state missing'}
$saved=Import-Clixml $projects[0].FullName
$expected=if($FailAt -eq 4){'Partial'}else{'Failed'}
$stage=if($FailAt -eq 1){'Manager'}elseif($FailAt -eq 2){'Developer'}else{'Analyst/Developer'}
if($saved.LLMProvider -ne 'AzureOpenAI' -or $saved.AzureOpenAIProtocol -ne 'Responses' -or $saved.MaxTokens -ne 10240 -or $saved.AzureResponsesTimeoutSec -ne 60 -or $saved.Stream -or $saved.RAG -or -not $saved.NOTips -or -not $saved.NOPM -or -not $saved.NODocumentator){throw 'Saved configuration changed'}
if($saved.WorkflowOutcome -ne $expected -or $saved.FailedStage -ne $stage -or $saved.WorkflowErrorCode -ne 'StageFailed'){throw 'Persisted workflow outcome/stage missing'}
$final=Join-Path $saved.TeamDiscussionDataFolder TheCodeF.py
if($FailAt -eq 4){
 $code=Get-Content $final -Raw
 if($code -notmatch 'def greet' -or $code -match 'import greet|subprocess|unittest' -or $code.Trim() -ne $saved.LastpydevCode.Trim()){throw 'Last good production export changed'}
}else{if($saved.LastpydevCode -or (Test-Path $final)){throw 'Initial failure created empty final draft'}}
@{pass=$true;posts=$global:posts;blocked=$global:denied;outcome=$saved.WorkflowOutcome;stage=$saved.FailedStage;project=$projects[0].FullName;sourceHash=(Get-FileHash $entry).Hash}|ConvertTo-Json|Set-Content (Join-Path $EvidenceRoot contract.json) -Encoding UTF8
