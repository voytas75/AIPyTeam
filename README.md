# AI Python Team (AIPyTeam)

AIPyTeam is a PowerShell-driven Python draft generator. It simulates a team of agents that propose requirements, code, review feedback and documentation using Azure OpenAI, Ollama, LM Studio or llama.cpp, with optional web retrieval.

**Beta:** generated Python requires human review and testing. AIPyTeam does not execute it or certify production readiness. Prompts, code and retrieved context may be sent to providers; do not include secrets or sensitive data without authorization.

## Requirements

- Native Windows PowerShell 5.1 or PowerShell 7.
- `PSAOAI` >= 0.3.2 and `PowerHTML`, required globally even with `-NORAG` or `-ReducedWorkflow`. Controlled qualification used PSAOAI 0.7.0 / PowerHTML 0.2.0.
- Startup reuses an eligible loaded PSAOAI without forced reinitialization; see [startup banners](docs/troubleshooting.md#duplicate-psaoai-startup-banner).
- A working backend configured before launch; see [provider configuration](docs/provider-configuration.md).
- Python is not a generator dependency. PSScriptAnalyzer does not validate Python and is not required.

## Installation and version boundaries

If modules are missing, install them explicitly in your own console:

```powershell
Install-Module -Name PSAOAI -MinimumVersion 0.3.2 -Scope CurrentUser
Install-Module -Name PowerHTML -Scope CurrentUser
```

Run `AIPyTeam.ps1` from a checkout directory. The documentation describes the **current local script**, including the approved, uncommitted `NOInteraction`, `ReducedWorkflow` and llama.cpp changes. Its version remains 0.1.0; this is not a claim that 0.1.0 or these modes are published.

```powershell
Install-Script -Name AIPyTeam -Scope CurrentUser
```

This optional Gallery command installs the published version, which may be older and lack these parameters. Its current availability was not checked for this documentation change. Historical release preparation used 0.0.3 as the published baseline. See [release notes](docs/ReleaseNotes.md) before substituting an installed script for the checkout. Startup/module update checks can contact Gallery; unattended mode is not an offline dependency-bootstrap guarantee.

## First run: a small Python draft

Configure Azure securely through [PSAOAI](https://github.com/voytas75/PSAOAI) in the same Windows user/session. Reuse existing Process `PSAOAI_API_AZURE_OPENAI_ENDPOINT` and `PSAOAI_API_AZURE_OPENAI_KEY`; Windows DPAPI credentials are decoded only in memory. Never place keys in commands, project files, chat or transcripts.

From the checkout directory, with the existing Process deployment configured:

```powershell
.\AIPyTeam.ps1 -UserInput 'Create a single-file Python greeting CLI using only the standard library' -DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT -NOInteraction -ReducedWorkflow -NORAG -MaxTokens 10240 -AzureResponsesTimeoutSec 120
```

- `-NOInteraction` disables AIPyTeam prompts and menu, failing on missing active provider configuration before discovery/inference. Dependency `#Requires` resolution still precedes script execution.
- `-ReducedWorkflow` keeps Manager → Developer, draft export and final state save; it skips reviews, documentation and final PM report. It does not disable RAG implicitly.
- `-NORAG` disables web retrieval, not model calls. This successful reduced profile uses two requests; it enforces no global request cap.
- Fresh Azure defaults to Responses with omitted Stream=false. Streaming/SSE is unsupported for Responses.
- 10240 tokens / HTTP120s is an explicit historical transport profile, **not** the product defaults of 20480 / HTTP60s, a workflow deadline or fresh live acceptance of current bytes.

For concise console output, append `-MinimalOutput`: English startup settings and explicitly supplied parameter descriptions, processing notices and confirmed export/save notices instead of model text. It is invocation-only and independent of `-NOInteraction` and `-NOLog`; logs may still contain complete model text. Dependency banners from `#Requires` are not suppressed.

## Results and recovery

Use the reported timestamped project directory (default root `MyDocuments/AIPyTeam`, or `-LogFolder`). It can contain versioned Python drafts, final `TheCodeF.py`, logs and saved `Project.xml`.

- `WorkflowOutcome=Completed` records workflow/persistence success, not runnable Python certification.
- `Partial` retains last-good code after a failed stage; `Failed` has no draft. Legacy state uses `NotRecorded`.
- Failed stages stop automatic downstream requests. Failed saves are reported separately; an unsaved state is not persisted success.

```powershell
.\AIPyTeam.ps1 -LoadProjectStatus 'C:\Projects\MyProject\Project.xml' -DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT -NOInteraction
```

Recovery honors saved settings and does not certify completion. Keep independent backups and review generated code before testing it. `-NOLog` also suppresses final Python export; it is not merely quiet output. There is no automatic production Python validation. See [usage and recovery](docs/usage.md).

## Documentation

- [Provider configuration](docs/provider-configuration.md): secure Azure and local backend setup.
- [Usage and parameters](docs/usage.md): modes, full workflow, outputs and recovery.
- [RAG](docs/rag.md): optional SerpApi → EXA → Serper retrieval and data handling.
- [Troubleshooting](docs/troubleshooting.md): startup, transport and draft failures.
- [llama.cpp](docs/llama-cpp.md): dedicated local provider, buffered SSE and recovery.
- [Azure Responses](docs/azure-responses.md): protocol contract and historical evidence.
- [Developer guide](docs/developer-guide.md): implementation, qualification and manual release boundaries.
- [Offline CI](docs/ci.md) · [Release notes](docs/ReleaseNotes.md)

Maintainers: [active stabilization checkpoint](docs/stabilization-plan.md#active-checkpoint-approved-llamacpp-local-candidate). Historical handoff artifacts do not qualify the changed current source.
