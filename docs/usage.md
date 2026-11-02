# Usage and recovery

[README](../README.md) · [Provider configuration](provider-configuration.md) · [RAG](rag.md) · [Troubleshooting](troubleshooting.md)

All commands below run from the checkout directory and describe current local source. They request a Python draft; they do not run a system monitor, backup, audit or the generated Python. Review cost, permissions and output before testing. Installed Gallery versions may not support the current switches.

## Input and workflow

Use `-UserInput` or a scalar pipeline description. A synthetic, standard-library greeting CLI is the recommended first draft. Broader requests can describe CSV reports, RAM/CPU/disk monitors, network latency/bandwidth plots, event-log summaries, uptime or disk-health tools; these are possible generation tasks, not guaranteed tested applications. Plotting and platform-specific tasks may require generated dependencies.

```powershell
'Create a Python CLI that reports disk usage using the standard library' | .\AIPyTeam.ps1 -DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT -NOInteraction -ReducedWorkflow -NORAG -MaxTokens 10240 -AzureResponsesTimeoutSec 120
```

| Option | Effect |
| --- | --- |
| `UserInput` | Fresh project description; NOInteraction requires nonblank input. |
| `NOInteraction` | Invocation-only: suppresses AIPyTeam questions and menu; not persisted. Validates active configuration before discovery/inference. |
| `ReducedWorkflow` | Persisted Manager/Developer-only workflow; fresh and legacy default false, saved value wins on recovery. |
| `NORAG` | Disables retrieval for a fresh project; not implicit in reduced mode. Saved RAG wins on load. |
| `NOPM` | Omits final PM report, not the initial Manager stage. |
| `NODocumentator` | Omits documentation stage. |
| `NOLog` | Disables team file logging/transcript and gates final export; not simply quiet or a Python validation switch. |
| `LogFolder` | Output root; default `MyDocuments/AIPyTeam`, with a timestamped child folder. |
| `LLMProvider` | AzureOpenAI, LMStudio, ollama and llama.cpp are implemented; OpenAI is a placeholder. |
| `DeploymentChat` | Azure deployment value; pass the existing Process environment value explicitly. |
| `AzureOpenAIProtocol` | Fresh Azure Responses default; ChatCompletions compatibility path. Saved selector wins. |
| `Stream` | Boolean; fresh Responses omitted=false, Chat/local omitted=true; saved value wins. |
| `MaxTokens` | Fresh default 20480; Responses forwards as max_output_tokens, reasoning plus visible output; llama.cpp forwards max_tokens. |
| `LlamaCppModel` | Exact advertised llama.cpp model ID; omission selects the first on fresh startup. |
| `LlamaCppTimeoutSec` | llama.cpp discovery/completion HTTP timeout, default 240 seconds (1–3600); saved value wins when omitted. |
| `AzureResponsesTimeoutSec` | Fresh Responses HTTP timeout default60; not a whole-workflow deadline or local/Chat timeout control. |
| `NOTips` / `VerbosePrompt` | Disable prompt tips / display prompts; neither is a security or execution safeguard. |
| `LoadProjectStatus` | Load saved state rather than starting fresh. |

Full workflow retains Manager → Developer, four reviewer/revision pairs (Analyst, Architect, Domain Expert, QA), optional Documentation and final Project report. Reduced mode skips all four pairs and both optional reports regardless of NOPM/NODocumentator, retaining draft export and final state save. With NORAG, successful reduced uses two inference requests; full with NOPM/NODocumentator uses ten, and full with both reports uses twelve. These are path counts, not global enforced request caps; retrieval and explicit menu actions can add calls. Failures stop automatic downstream stages.

For a fuller review with both reports omitted, remove reduced mode explicitly from a fresh invocation:

```powershell
.\AIPyTeam.ps1 -UserInput 'Create a standard-library Python CSV summary CLI' -DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT -NOInteraction -NORAG -NOPM -NODocumentator -MaxTokens 10240 -AzureResponsesTimeoutSec 120 -LogFolder 'C:\Projects\AIPyTeamDrafts'
```

## Outputs and failure states

Logs and transcripts may contain prompts, generated code and provider output. Keep them private until sanitized. Versioned drafts and final `TheCodeF.py` are extraction artifacts, not executed programs. Export retains section4 production/helpers, excludes Usage and explicitly labelled development-only tests, and rejects ambiguous boundaries without overwriting last-good code. Generated usage prose may name `greet.py` rather than the actual output file: inspect it rather than executing it blindly.

`Project.xml` stores effective provider, protocol, Stream, bounds, flags, folder and workflow outcome. `Completed` means workflow/persistence success, not syntax or runtime certification. `Partial` means a retained last-good draft after failure; `Failed` has no draft; legacy missing outcome is `NotRecorded`. `FailedStage` and a fixed safe `WorkflowErrorCode` describe failure. Initial failure does not create an empty final Python file. Save failures are separate and do not announce completed persistence.

Keep NOLog off for the first draft: intermediate Save-AndUpdateCode exports remain, but NOLog suppresses final TheCodeF.py export. Get-SourceCodeAnalysis is an explicit menu action, not automatic final validation or a production Python AST validator. Offline qualification used Python ast.parse separately and never executed generated code.

## Recovery and menu

```powershell
.\AIPyTeam.ps1 -LoadProjectStatus 'C:\Projects\MyProject\Project.xml' -DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT -NOInteraction
```

Use an explicit XML file. NOInteraction also accepts a directory containing exactly one XML file; zero/multiple candidates fail. No new UserInput is needed. Active provider/RAG configuration is still required by unattended preflight, and local startup may perform discovery HTTP. Recovery does not automatically rerun the generation workflow and loading alone never completes an interrupted project.

Saved folder/provider/protocol/Stream/outcome/ReducedWorkflow take precedence; legacy ReducedWorkflow defaults false. Legacy protocol defaults ChatCompletions unless explicitly supplied. Saved Responses Stream=true rejects before HTTP; do not expect CLI Stream to silently repair it. Keep independent backups: state saving is not atomic.

For llama.cpp, recovery revalidates the saved model using current Process endpoint/optional key; omitted model/timeout retain saved values, explicit model/timeout/Stream override them. NOInteraction recovery has discovery GET only, zero POSTs and preserves outcome. See [llama.cpp](llama-cpp.md); its default true SSE is buffered, not live display.

Omit NOInteraction for the menu. Explicit menu operations can request features, analysis or documentation and may invoke providers; they do not retroactively certify an interrupted automatic workflow. For configuration and saved-state failures, see [troubleshooting](troubleshooting.md).
