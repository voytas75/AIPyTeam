# Developer and release guide

[README](../README.md) · [Offline CI](ci.md) · [Release notes](ReleaseNotes.md) · [Stabilization checkpoint](stabilization-plan.md)

## Implementation map

- `AIPyTeam.ps1`: metadata, parameters, startup, workflow and saved state.
- `ProjectTeam`: agent roles, memory, logging; methods include ProcessInput, Feedback, AddLogEntry, Notify and SummarizeMemory.
- `SendFeedbackRequest` and `Invoke-ProcessFeedbackAndResponse`: review/revision requests.
- `Export-AndWritePythonCodeBlocks` and `Save-AndUpdateCode`: section-aware Python extraction and draft updates. The obsolete PowerShell-export name does not describe this implementation.
- `Invoke-LLMChatCompletion`: provider dispatch; OpenAI selector is a placeholder.
- `New-AIPyTeamResponsesRequest`, `Read-AIPyTeamResponsesResponse`, `Invoke-AIPyTeamAzureResponses`: Azure Responses contract.
- `Get-ProjectState` / `Save-ProjectState`: persistence; `Get-SourceCodeAnalysis` is not a production Python AST validator.
- `tools/tests/` and `tools/Invoke-OfflineCI.ps1`: source-bound offline contracts and orchestration; `.github/workflows/` owns CI configuration.

## Qualification boundaries

Current approved llama.cpp source SHA256 is `ac7412dea65b929ca2d16091e5b67aeee65e21cf31a800c2c122ced72d53dcc2`; prior mode source `1436ddefe336980fba5980305ffbb67c43a431f848dbb8f44ee73bcc06fce04d` remains historical. Source/tests/helper and the documentation restructure were already dirty before this closeout. The active [checkpoint](stabilization-plan.md#active-checkpoint-approved-llamacpp-local-candidate) records native Windows PowerShell5.1/7 final receipts, eight suites/124 cases per runtime including 39 llama.cpp cases. Exact executable/test bytes still match native staging; documentation closeout is not a new full test run or remote CI activation.

Offline original-entry fixtures use controlled transport/dependencies; command guards are not an OS network sandbox. They do not qualify live providers, unguarded dependency bootstrap, arbitrary interactive UI, live RAG or generated Python execution. Separate Python ast.parse checks prove syntax only. Historical full120 transport success and older live diagnostics bind earlier source, not current mode bytes. Keep active user contracts separate from the historical ledger in [Azure Responses](azure-responses.md) and the maintainer tracker.

## Manual release and packaging ownership

The source version remains 0.1.0; no version/publication decision is made by this docs change. Gallery availability is unverified here. Historical release preparation recorded 0.0.3 as the published baseline, and its 0.1.0 handoff covered older bytes. That handoff is **superseded for the current source**: do not publish the changed script using its frozen ZIP/package/manifest. Those immutable artifacts remain historical and were not rebuilt.

A later approved release must separately select/version the payload, qualify exact bytes and metadata on native5.1/7, freeze hashes and prepare new publication artifacts. A ZIP is a transport bundle, not a Gallery upload format; official Publish-Script publishes an extracted frozen script and regenerates its package. Publication is manual by the owner, with hidden local credential entry, no literal keys/transcripts, and exact-version/package readback afterwards. Repository delivery, Windows owner sync and Gallery publication are distinct actions; offline checks do not imply any of them.

Use the [active operational tracker](stabilization-plan.md) for decision/evidence paths rather than copying its ledger into user onboarding. No new packager, dependencies, release ZIP, security settings or CI behavior belongs to this documentation restructure.
