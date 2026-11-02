param([string]$RepositoryRoot,[string]$EvidenceRoot,[string]$PreflightCase)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
if($PreflightCase){
 $calls=0;$reads=0;$imports=0
 $modules=Join-Path $EvidenceRoot 'modules'
 foreach($name in 'PSAOAI','PowerHTML'){$dir=Join-Path $modules $name;New-Item -ItemType Directory -Force $dir|Out-Null;"@{RootModule='$name.psm1';ModuleVersion='0.3.2';GUID='$([guid]::NewGuid())'}"|Out-File (Join-Path $dir "$name.psd1") -Encoding utf8;''|Out-File (Join-Path $dir "$name.psm1") -Encoding utf8}
 $env:PSModulePath=$modules+[IO.Path]::PathSeparator+$env:PSModulePath
 function global:Read-Host {$script:reads++;throw 'Input forbidden'}
 function global:Import-Module {param($Name,[switch]$Force) if($Force){$script:imports++;throw 'Bootstrap forbidden'};Microsoft.PowerShell.Core\Import-Module -Name $Name}
 function global:Invoke-RestMethod {$script:calls++;throw 'Transport forbidden'}
 function global:Invoke-WebRequest {$script:calls++;throw 'Transport forbidden'}
 foreach($name in 'PSAOAI_API_AZURE_OPENAI_ENDPOINT','PSAOAI_API_AZURE_OPENAI_KEY','SERPAPI_API_KEY','EXA_API_KEY','SERPER_API_KEY','OPENAI_API_BASE'){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
 $args=@{NOInteraction=$true;NORAG=$true;DeploymentChat='opaque-alias'}
 if($PreflightCase -ne 'missing-input'){$args.UserInput='synthetic'}
 if($PreflightCase -eq 'null-input'){$args.UserInput=$null}
 if($PreflightCase -eq 'empty-input'){$args.UserInput=''}
 if($PreflightCase -eq 'blank-input'){$args.UserInput='   '}
 if($PreflightCase -eq 'missing-rag'){$args.Remove('NORAG');$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid';$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic'}
 if($PreflightCase -eq 'missing-lm-endpoint'){$args.LLMProvider='LMStudio'}
 if($PreflightCase -eq 'ambiguous-recovery'){
  foreach($n in 'a.xml','b.xml'){[pscustomobject]@{UserInput='synthetic'}|Export-Clixml (Join-Path $EvidenceRoot $n)}
  $args.LoadProjectStatus=$EvidenceRoot
 }
 $caught=$false
 try{& (Join-Path $RepositoryRoot AIPyTeam.ps1) @args}catch{$caught=$true;$message=$_.Exception.Message}
 if(-not $caught -or $message -notmatch 'NOInteraction' -or $calls -or $reads -or $imports){throw "Preflight failed: caught=$caught message=$message calls=$calls reads=$reads imports=$imports"}
 @{pass=$true;calls=$calls;reads=$reads;imports=$imports;message=$message}|ConvertTo-Json|Set-Content (Join-Path $EvidenceRoot preflight.json)
 exit 0
}
$native=(Get-Process -Id $PID).Path
$rows=@()
foreach($case in @(@{name='description-recovery';args=@('-DescriptionCase','recovery','-Resume')},@{name='description-recovery-nointeraction';args=@('-DescriptionCase','recovery-nointeraction','-Resume','-NOInteraction')},@{name='description-missing';args=@('-DescriptionCase','missing','-ReducedWorkflow','-MinimalOutput')},@{name='description-empty';args=@('-DescriptionCase','empty','-ReducedWorkflow')},@{name='description-whitespace-full';args=@('-DescriptionCase','whitespace','-MinimalOutput')},@{name='reduced';args=@('-NOInteraction','-ReducedWorkflow','-OmitSkipFlags')},@{name='pipeline';args=@('-NOInteraction','-ReducedWorkflow','-PipelineScalar')},@{name='lm-nokey';args=@('-NOInteraction','-ReducedWorkflow','-LMStudio')},@{name='lm-key';args=@('-NOInteraction','-ReducedWorkflow','-LMStudio','-WithKey')},@{name='rag';args=@('-NOInteraction','-ReducedWorkflow','-ConfiguredRAG')},@{name='late-failed';args=@('-NOInteraction','-FailAt','4')},@{name='late-rejected';args=@('-NOInteraction','-LateRejected')},@{name='save-failed';args=@('-NOInteraction','-ReducedWorkflow','-FailedSave')},@{name='full';args=@('-NOInteraction')},@{name='manager-failed';args=@('-NOInteraction','-ReducedWorkflow','-FailAt','1')},@{name='developer-failed';args=@('-NOInteraction','-ReducedWorkflow','-FailAt','2')},@{name='developer-rejected';args=@('-NOInteraction','-ReducedWorkflow','-RejectDeveloper')},@{name='legacy-recovery';args=@('-NOInteraction','-ReducedWorkflow','-Resume')},@{name='saved-reduced-recovery';args=@('-NOInteraction','-Resume','-SavedReduced')},@{name='partial-recovery';args=@('-NOInteraction','-Resume','-PartialRecovery')})){
 $out=Join-Path $EvidenceRoot $case.name
 $ErrorActionPreference='Continue'
 & $native -NoProfile -NonInteractive -File (Join-Path $RepositoryRoot tools/tests/Test-ResponsesEntrypoint.ps1) -RepositoryRoot $RepositoryRoot -EvidenceRoot $out @($case.args) *> (Join-Path $EvidenceRoot ($case.name+'.log'))
 $code=$LASTEXITCODE;$receipt=Join-Path $out entrypoint.json
 $ok=$code -eq 0 -and (Test-Path $receipt)
 if($ok){$ok=(Get-Content $receipt -Raw|ConvertFrom-Json).pass -eq $true}
 if($case.name -eq 'save-failed'){$log=Get-Content (Join-Path $EvidenceRoot ($case.name+'.log')) -Raw;$ok=$ok -and $log -match 'Workflow outcome: Partial; failed stage: SaveProjectState' -and $log -notmatch 'Your progress on Project has been saved'}
 if($case.name -like 'description-*' -and $case.name -ne 'description-recovery-nointeraction'){
  $log=Get-Content (Join-Path $EvidenceRoot ($case.name+'.log')) -Raw
  $ok=$ok -and ([regex]::Matches($log,[regex]::Escape('++ Project description is required. Enter a nonblank description.')).Count -eq 4)
  if($case.args -contains '-MinimalOutput'){$ok=$ok -and $log -notmatch 'Synthetic original task'}
 }
 $rows+=@{name=$case.name;pass=$ok;exitCode=$code}
}
foreach($name in 'missing-input','null-input','empty-input','blank-input','missing-config','missing-rag','missing-lm-endpoint','ambiguous-recovery'){
 & $native -NoProfile -NonInteractive -File $PSCommandPath -RepositoryRoot $RepositoryRoot -EvidenceRoot (Join-Path $EvidenceRoot $name) -PreflightCase $name *> (Join-Path $EvidenceRoot ($name+'.log'))
 $rows+=@{name=$name;pass=($LASTEXITCODE -eq 0);exitCode=$LASTEXITCODE}
}
@{sourceHash=(Get-FileHash (Join-Path $RepositoryRoot AIPyTeam.ps1)).Hash;cases=$rows}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot receipt.json) -Encoding UTF8
if(@($rows|Where-Object {-not $_.pass}).Count){exit 1}
exit 0
