# Offline CI

[README](../README.md) · [Developer guide](developer-guide.md)

The current local helper requires eight suites / 124 cases per native runtime. Existing native Windows PowerShell 5.1 and PowerShell 7 final receipts pass against current source SHA256 `ac7412dea65b929ca2d16091e5b67aeee65e21cf31a800c2c122ced72d53dcc2`; this documentation closeout does not rerun those unchanged source/test bytes. The previous remote CI remains the older 64-case/source binding; the new helper suites run in Actions only after a separately approved push, not yet remotely activated.

The existing Ubuntu main-script parser gate and its push/PR/manual triggers remain unchanged. The Windows job dispatches native `powershell.exe` (5.1) and `pwsh.exe` (7) from fixed `shell: pwsh` orchestration and checks the actual native exit code.

Run locally from a Windows checkout, with a fresh directory outside the repository:

```powershell
powershell.exe -NoProfile -NonInteractive -File ./tools/Invoke-OfflineCI.ps1 -RepositoryRoot $PWD -EvidenceRoot "$env:TEMP/aipyteam-ci-51-new"
if ($LASTEXITCODE -ne 0) { throw 'Offline CI failed' }
pwsh.exe -NoProfile -NonInteractive -File ./tools/Invoke-OfflineCI.ps1 -RepositoryRoot $PWD -EvidenceRoot "$env:TEMP/aipyteam-ci-7-new"
if ($LASTEXITCODE -ne 0) { throw 'Offline CI failed' }
```

The helper parses repository-owned `.ps1` files before execution, then runs each existing suite in a fresh same-runtime child:

| Runner | Required passing cases |
| --- | ---: |
| Test-WorkflowOutcome | 8 |
| Test-AzureDefaults | 12 |
| Test-Stabilization | 13 |
| Test-AzureResponses | 16 |
| Test-ResponsesHttpError | 4 |
| Test-PythonExportIntegrity | 11 |
| Test-WorkflowModes | 21 |
| Test-LlamaCpp | 39 |
| **Per native runtime** | **124** |

Child exit codes, exact receipt counts, boolean passing flags, available source hashes and parser results are checked. Startup in AzureDefaults is an original-source parameter/functions/startup fixture with dependency imports guarded; it is not a complete production workflow. Transport is controlled by existing suite fixtures. The child clears relevant inherited provider Process settings and guards interactive input, Gallery/install commands, external module imports and unguarded PowerShell HTTP commands. These are command-level guards, not an OS network sandbox. No dependencies, secrets, real modules or provider requests are required.

WorkflowModes invokes the original product filepath in fresh native processes with owned dependency fixtures and controlled transport, checking reduced/full counts, failures, recovery and preflight stops. Its opt-in entry runner remains usable separately. Test-AzureBudget and Test-RealDependencyPreflight require installed dependency state and remain excluded; real local-server acceptance and live integrations remain separate. Test-LlamaCpp adds source-bound parsing/request contracts and original-filepath fresh/recovery/failure fixtures: buffered SSE/JSON, optional Bearer discovery/completion, model validation, saved settings, 2/10 POST success paths and fail-stop. In-memory HttpMessageHandler does not qualify actual networking/TLS or stream performance. Actual exported Python is syntax-parsed separately without execution; sentinel fixtures are counted distinctly. See [llama.cpp](llama-cpp.md). No generated Python execution, production Python validator, interpreter setup or publication qualification is introduced.

Only helper-owned `artifacts/*.json` and `artifacts/*.log` are uploaded, even on failure, with missing artifacts treated as an error and seven-day retention. Synthetic project state, prompt fixtures, generated scripts and module fixtures are not uploaded. `actions/checkout@v4` is preserved; `actions/upload-artifact@v4` is a verified existing tag.

This feature/CI change is local until separately approved commit/push and exact-SHA Actions verification. The old handoff is superseded for changed product source; its immutable historical package is not rebuilt here.
