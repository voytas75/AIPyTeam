# Provider configuration

[README](../README.md) · [Usage](usage.md) · [Azure Responses](azure-responses.md) · [RAG](rag.md)

These settings describe the current checkout, not an unverified Gallery release. Configure the backend before invoking the script. Do not create parallel environment-variable names or put API keys inline. Use existing approved session configuration; do not print credentials or share transcripts containing them.

## Azure OpenAI

Azure is the default provider. Fresh projects use Responses; select `-AzureOpenAIProtocol ChatCompletions` only for the explicit compatibility path supported by your deployment.

| Setting | Current contract |
| --- | --- |
| `PSAOAI_API_AZURE_OPENAI_ENDPOINT` | Responses reads Process only; HTTPS resource root or `/openai/v1/`, no query, fragment or user information. |
| `PSAOAI_API_AZURE_OPENAI_KEY` | Responses reads Process only; reuse PSAOAI secure configuration. Windows DPAPI is decoded in memory under the same Windows user. |
| `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT` | Pass explicitly via `-DeploymentChat $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`. The parameter's historical default reads User; NOInteraction resolves an omitted deployment from Process. |
| `PSAOAI_API_AZURE_OPENAI_APIVERSION` | Dated API version for the PSAOAI Chat path only; ignored by Responses. |
| `PSAOAI_BANNER` | Script sets Process value `0`; not a quiet-output contract. |

Responses has no User/Machine fallback. Existing User settings must already be inherited into the launching Process or securely configured there. Chat delegates to PSAOAI; do not assume the Responses resolver or unsupported sibling endpoint overrides apply to it. Credentials are not saved in Project.xml.

Omitted Stream is false for fresh Azure Responses and true for Chat/local providers. Saved Stream wins on recovery, even when incompatible: Responses with Stream=true fails before HTTP. Responses omits sampling fields, sets store=false, admits completed nonempty text only and has no retry/fallback. See [protocol details](azure-responses.md).

## LM Studio

Start the model server and load a model first. `OPENAI_API_BASE` is the API URL, **not** a model name. Interactive startup resolves Process → User → `http://localhost:1234/v1`; NOInteraction requires a nonblank Process URL rather than relying on the default. `OPENAI_API_KEY` resolves Process → User → the local placeholder `lm-studio`; authentication is optional when the server allows it. Configure an authenticated server's key securely outside the example.

```powershell
$env:OPENAI_API_BASE = 'http://localhost:1234/v1'
.\AIPyTeam.ps1 -UserInput 'Create a Python CLI that summarizes a local CSV file' -LLMProvider LMStudio -Stream $false -NOInteraction -ReducedWorkflow -NORAG
```

Startup requests `/models` with a Bearer header and selects the first returned model id. Empty discovery fails closed. Endpoint readiness/discovery still uses HTTP; NOInteraction is not a no-network switch.

## Ollama

Start Ollama and a model outside AIPyTeam first. `OLLAMA_ENDPOINT` resolves Process → User → `http://localhost:11434/` and is normalized with a trailing slash. The active startup path checks the API and running model; it fails when none is running. In NOInteraction it uses the discovered running model directly, rather than prompting to start/select one. Do not assume merely setting `OLLAMA_MODEL` starts or selects a model in this path.

```powershell
$env:OLLAMA_ENDPOINT = 'http://localhost:11434/'
.\AIPyTeam.ps1 -UserInput 'Create a Python disk-usage summary CLI' -LLMProvider ollama -Stream $false -NOInteraction -ReducedWorkflow -NORAG
```

## llama.cpp

Select `-LLMProvider 'llama.cpp'` with a loaded server/model and required Process `LLAMACPP_ENDPOINT`; optional Process `LLAMACPP_API_KEY` supplies Bearer authentication to discovery and completion. `-LlamaCppModel` selects an exact advertised ID; omission selects the first. Default Stream=true uses buffered SSE, not live incremental display; `-Stream $false` uses JSON. `-MaxTokens` forwards `max_tokens`; `-LlamaCppTimeoutSec` defaults to 240 seconds per HTTP request. See [llama.cpp configuration and recovery](llama-cpp.md) for saved-model/timeout overrides and the offline-only qualification boundary.

## Unsupported selector

`OpenAI` is accepted by parameter validation but its dispatched branch is a placeholder, not an implemented public OpenAI backend. A Process key satisfying preflight does not implement inference. Use an implemented provider instead.

## Dependency boundary

PSAOAI and PowerHTML are globally required, irrespective of backend, RAG or reduced workflow. NOInteraction validates active Process settings before the script's explicit module bootstrap, but PowerShell `#Requires` can resolve/import dependencies earlier. Module/bootstrap/update behavior is not qualified as prompt-free or offline with arbitrary installed dependencies.
