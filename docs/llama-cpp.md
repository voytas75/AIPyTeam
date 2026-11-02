# llama.cpp

[README](../README.md) · [Provider configuration](provider-configuration.md) · [Usage](usage.md)

Select the dedicated provider with `-LLMProvider 'llama.cpp'`. Start your llama.cpp HTTP server and load a model yourself before launching AIPyTeam. The script does not install/start servers, download models or change GPU/security settings. PSAOAI >= 0.3.2 and PowerHTML remain globally required.

## Session configuration

- `LLAMACPP_ENDPOINT`: required Process setting, server root or `/v1`, with optional trailing slash. HTTP(S) only; no URL credentials, query or fragment. Both forms resolve to `/v1/models` and `/v1/chat/completions`.
- `LLAMACPP_API_KEY`: optional Process setting. A nonblank key is sent as Bearer authentication to both discovery and completion; absent keys omit Authorization. Configure it securely outside commands/transcripts.
- No User/Machine fallback, persistent environment writes, duplicate credential variables or `LLAMACPP_MODEL` setting are introduced. Existing User settings must already be inherited into the launching Process.
- `-LlamaCppModel`: exact, case-sensitive advertised model ID. An explicit blank or unavailable ID fails closed. Omitted fresh selection uses the first advertised model without prompting. Invalid/empty catalogues and authentication failures stop before completion.

```powershell
$env:LLAMACPP_ENDPOINT = 'http://localhost:8080'
.\AIPyTeam.ps1 -UserInput 'Create a single-file Python greeting CLI using only the standard library' -LLMProvider 'llama.cpp' -NOInteraction -ReducedWorkflow -NORAG -MaxTokens 1024 -LlamaCppTimeoutSec 120
```

To select a particular model, add `-LlamaCppModel 'your-exact-advertised-id'`; this placeholder must be replaced with the ID your server advertises, not a presumed filename.

## Transport and outcomes

Local default Stream remains true. The adapter consumes Chat Completions SSE content deltas and requires `[DONE]` plus nonempty text. SSE is **buffered**, not incrementally displayed: HttpClient bounds the complete HTTP response. `-Stream $false` selects JSON `choices[0].message.content`. HTTP failure, malformed events/JSON, stream error, missing terminal marker or empty text fail the stage; they are not completed responses. No Responses API migration, adapter retry or fallback is added.

`-MaxTokens` forwards to `max_tokens`. `-LlamaCppTimeoutSec` bounds each discovery/completion HTTP request (default 240 seconds, allowed 1–3600, matching the inspected sibling adapter). It is not a total workflow deadline or measured performance guarantee. A successful ReducedWorkflow + NORAG run has one discovery GET and two completion POSTs. The full review profile with NOPM/NODocumentator has one GET and ten POSTs; enabling those optional stages adds their existing calls.

## Recovery

Project.xml saves provider, selected model, effective Stream and llama.cpp timeout, never the adapter key or endpoint. Recovery re-resolves current Process endpoint/key and revalidates model discovery. Saved model/timeout win when their parameters are omitted; explicit llama.cpp model/timeout/Stream override saved values. Invalid saved model/timeout fails closed. Missing legacy model fields choose the first discovered model. NOInteraction recovery performs discovery but no completion POSTs and preserves prior workflow outcome; it does not certify generation.

## Qualification boundary

The local uncommitted candidate is qualified offline on native Windows PowerShell 5.1 and PowerShell 7 using source-bound contracts and the original entrypoint with owned module fixtures, intercepted discovery and in-memory HttpMessageHandler completion transport. No real server/model, TLS, real dependency full entry, latency or generated-code execution was tested. See [CI](ci.md) and the [checkpoint](stabilization-plan.md). Existing manual handoff is superseded for changed source; no version bump, commit/push, owner-checkout sync or publication occurs in this slice.
