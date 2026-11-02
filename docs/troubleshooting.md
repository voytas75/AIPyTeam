# Troubleshooting

[README](../README.md) · [Provider configuration](provider-configuration.md) · [Usage](usage.md) · [Azure Responses](azure-responses.md)

## Script or module not found

Run `.\AIPyTeam.ps1` from the checkout directory. A Gallery installation is a different version/location and may reject NOInteraction or ReducedWorkflow. Locate an installed copy with `Get-InstalledScript -Name AIPyTeam`; do not assume it matches local source. Check the source/version you actually invoked.

PSAOAI >=0.3.2 and PowerHTML are globally required. Install missing modules explicitly using the [README instructions](../README.md#requirements); do not change repository trust or execution policy to hide a dependency error. For filesystem permission failures, choose a writable LogFolder rather than routinely running as administrator. Startup/update checks and dependency resolution can contact Gallery; offline fixture tests do not prove arbitrary dependency bootstrap is offline.

## Duplicate PSAOAI startup banner

PowerShell `#Requires -Modules PSAOAI` imports the dependency before AIPyTeam executes. The former explicit `Import-Module -Force` initialized it again, producing two startup banners before the input prompt. Startup now uses `Import-Module -MinimumVersion 0.3.2` without Force: an eligible loaded module is reused; an older loaded version requires an installed qualifying version. If only an old version is available, startup stops before input or inference. Global PSAOAI and PowerHTML requirements remain unchanged.

This is an import correction, not banner suppression. A fresh dependency import can still print one banner; an already-loaded eligible module need not print another. AIPyTeam no longer overrides the Process PSAOAI_BANNER setting. Owned-module native tests verify import counts, not the real module bootstrap or its external diagnostics.

## NOInteraction stops before inference

Fresh input must be nonblank. Azure needs Process endpoint/key and deployment; LMStudio needs Process OPENAI_API_BASE even though interactive startup has a localhost default. Enabled RAG needs both Process Bing settings. Recovery needs an explicit XML file or a directory with exactly one XML file, and uses the saved active provider/RAG. Do not disable the fail-closed checks or insert literal credentials. See [provider setup](provider-configuration.md) and [RAG scopes](rag.md).

PowerShell #Requires resolves dependencies before these checks; the switch cannot guarantee no implicit imports/prompts inside dependencies. It suppresses AIPyTeam prompts/menu, not all output, discovery HTTP or provider calls.

## Local discovery fails

LMStudio must expose `/models` and return at least one model id; verify the configured URL and authorization in your server's own console. The first returned model is selected. Ollama must already expose its API and a running model; setting OLLAMA_MODEL alone does not start it. Do not confuse endpoint defaults with an operational model server.

## Azure request rejected or timed out

Responses requires an HTTPS resource root or `/openai/v1/`, shared Process credentials and a deployment. Windows DPAPI must be decodable by the current Windows user. APIVERSION is Chat-only. Stream=true, SSE, tools and server-side chaining are unsupported; omit Stream for a fresh Responses project or pass Stream=false. Saved Stream wins on recovery.

Incomplete/max_output_tokens, refusal, error, empty and tool-only Responses output are not admitted as a draft. A 10240 cap includes reasoning; HTTP120s is not a workflow deadline and does not establish model compatibility. There is no automatic retry or protocol fallback. Inspect safe failure metadata and the retained last-good draft before deciding on a separately authorized rerun. Historical 400/timeout diagnostics are not proof of every later failure's cause.

## Missing or partial Python output

Check WorkflowOutcome, FailedStage and WorkflowErrorCode in saved Project.xml and console output. Partial is retained last-good code, not a complete project; Failed has no draft. Ambiguous export boundaries reject without overwriting. NOLog suppresses final export as well as logging; keep it off during onboarding. An unsuccessful state save is not persisted completion.

Completed does not certify runnable Python. Validate syntax and dependencies separately in a safe environment after human review; generated code is never automatically executed. PSScriptAnalyzer is not a Python validator. Historical ast.parse checks are syntax-only and source-bound, not current live/runtime acceptance. Generated Usage filenames can differ from TheCodeF.py.

## Recovery or logs

Back up the project before recovery. Saved settings win over fresh CLI mode/protocol/Stream choices; loading is not automatic repair or completion. Logs/transcripts can contain input, code and responses: redact before sharing. Keep immutable historical qualification artifacts separate from current operational files; see the [maintainer guide](developer-guide.md).
