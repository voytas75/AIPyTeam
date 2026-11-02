# Offline CI

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
| **Per native runtime** | **64** |

Child exit codes, exact receipt counts, boolean passing flags, available source hashes and parser results are checked. Startup in AzureDefaults is an original-source parameter/functions/startup fixture with dependency imports guarded; it is not a complete production workflow. Transport is controlled by existing suite fixtures. The child clears relevant inherited provider Process settings and guards interactive input, Gallery/install commands, external module imports and unguarded PowerShell HTTP commands. These are command-level guards, not an OS network sandbox. No dependencies, secrets, real modules or provider requests are required.

Deliberately excluded: Test-AzureBudget and Test-RealDependencyPreflight assume actual installed PSAOAI/dependency state. Test-LocalStartup, Test-OfflineEntrypoint, Test-ResponsesEntrypoint and Test-OfflineResponsesFailure remain separate existing acceptance runners, not claimed CI coverage. This bounded gate does not validate production NOInteraction/ReducedWorkflow behavior, generated Python execution, live integrations or publication readiness. Existing Python export integrity assertions are retained; no additional Python interpreter/setup or AST gate is introduced.

Only helper-owned `artifacts/*.json` and `artifacts/*.log` are uploaded, even on failure, with missing artifacts treated as an error and seven-day retention. Synthetic project state, prompt fixtures, generated scripts and module fixtures are not uploaded. `actions/checkout@v4` is preserved; `actions/upload-artifact@v4` is a verified existing tag.

This change is a local CI candidate until separately approved commit/push and an exact-SHA GitHub Actions run. Product source and existing tests are unchanged. Existing handoff bytes/source binding are untouched; this CI change does not refresh or certify a handoff against new documentation provenance.
