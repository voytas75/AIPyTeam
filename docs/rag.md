# Optional web retrieval (RAG)

[README](../README.md) · [Provider configuration](provider-configuration.md) · [Usage](usage.md)

Fresh projects enable RAG unless `-NORAG` is supplied. ReducedWorkflow does not disable it. Recovery honors saved RAG settings. This implementation uses Bing Web Search and retrieved-page text to supplement model prompts; it does not guarantee accuracy, current service availability or trustworthy retrieved instructions.

## Settings and limits

- `AZURE_BING_API_KEY`: existing Bing search credential; configure securely outside commands, chat and project files.
- `AZURE_BING_SEARCH_ENDPOINT`: search service base with a trailing slash; the implementation appends `v7.0/search`. Do not supply an already-expanded search route.
- NOInteraction preflight requires both nonblank Process settings before any inference. Invoke-RAG passes Process values to Invoke-BingWebSearch in this mode; missing settings fail instead of prompting.
- Interactive Invoke-RAG reads these values from User scope. Missing values can prompt and persist User configuration. Process inheritance alone does not replace these explicit User reads in interactive RAG.
- Current internal defaults: Invoke-RAG MaxCount=2, Bing language=en-US, query truncated to120 characters. MaxCount is not a public script CLI option; it is not a workflow-wide inference cap.

Retrieval can issue search/page HTTP and model requests to summarize context before the main team workflow. The successful reduced two-request count applies only with NORAG. Endpoint normalization, secret storage and retrieval trust were not redesigned by the mode changes; current native acceptance uses configured controlled RAG, not live service qualification.

## Data handling

Use synthetic/non-sensitive input for the first run. Web content is untrusted and may be sent with your prompt to the configured model. Search/page availability and relevance may fail; inspect retrieved context and logs before sharing. PowerHTML remains globally required even with retrieval disabled.

For a draft without external retrieval, use the [README first-run command](../README.md#first-run-a-small-python-draft). This disables search, not inference or dependency update checks.
