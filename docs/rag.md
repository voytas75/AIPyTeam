# Optional web retrieval (RAG)

[README](../README.md) · [Provider configuration](provider-configuration.md) · [Usage](usage.md)

Fresh projects enable RAG unless `-NORAG` is supplied. ReducedWorkflow does not disable it. Recovery honors saved RAG, including legacy XML: saved true still needs current search configuration. Retrieval supplements model prompts with page text; it does not guarantee accuracy, freshness, service availability or trustworthy retrieved instructions.

## Settings and limits

Configure at least one nonblank Process environment key securely outside chat and project files:

- `SERPAPI_API_KEY`: SerpApi Google search, first choice.
- `EXA_API_KEY`: EXA search, second choice.
- `SERPER_API_KEY`: Serper Google search, third choice.

The names are shared with AIPSTeam. Both interactive and NOInteraction paths read Process only: no User fallback, key prompts or persistent User/Machine writes. Existing inherited Process settings are accepted. Legacy Bing credentials are no longer needed and are not changed or deleted. There are no configurable search endpoints and no keys or search endpoints saved in Project.xml. NOInteraction checks at least one configured key before module bootstrap, discovery or inference; it does not require all three. Saved RAG=false needs none.

Attempts are sequential in SerpApi → EXA → Serper order, skipping missing keys. The same generated query is passed unchanged to each attempt. Exceptions, empty results, malformed JSON and responses with no usable HTTP(S) URLs trigger the next configured provider. A nonempty accepted result stops fallback, avoiding three parallel billable searches. Total failure stops the RAG stage and automatic downstream workflow; no cleaner or next-agent completion follows a failed initial search.

Internal MaxCount defaults to 2 and is bounded to 1–10 accepted, exact-string-deduplicated HTTP(S) URLs. URL spelling/case is retained. Request num/numResults matches this bound, but services can return a different count; local admission enforces the limit. This is not a public CLI option or a workflow-wide cap. Search and page requests use TimeoutSec=10, one attempt per configured search provider and one request per accepted page, with no automatic retry. A page error or empty combined page text fails the stage rather than using stale content. There is no aggregate page-text budget or whole-workflow deadline.

Transport contracts are GET https://serpapi.com/search (engine=google, q, api_key, num), POST https://api.exa.ai/search (Authorization Bearer, query, root numResults, contents.text=true), and POST https://google.serper.dev/search (X-API-KEY, q, num). Results use organic_results.link, results.url and organic.link respectively; object responses and raw JSON are normalized. The EXA root numResults placement follows its published search schema rather than the reference's nested field. Inline EXA text is not consumed: existing PowerHTML page extraction, shared LLM dispatcher, cleaner and analysis remain in place.

Successful controlled initial/reduced RAG uses five model completions (query, cleaner, analysis, Manager, Developer); full RAG with optional reports omitted uses 25, including nested review retrieval. Search/page HTTP counts are separate and can increase through fallback. These are fixture path counts, not global enforced inference caps. Native offline tests do not establish live SerpApi/EXA/Serper API compatibility; a separately approved bounded live check remains necessary.

## Data handling

Search queries leave the machine for configured services; fetched page text is sent to the configured model. SerpApi authentication is in the request URL: do not share request URLs, headers, payloads or raw HTTP errors. Script transport verbosity is suppressed and fallback errors are fixed safe messages. Queries remain recorded in `websearchqueries.log`; model/team logs and transcript remain enabled and can contain complete context. MinimalOutput changes presentation only, not logging or privacy. Keep logs private and inspect context before sharing.

Use synthetic/non-sensitive input for acceptance. Web content is untrusted. PowerHTML remains globally required even with retrieval disabled. For a draft without external retrieval, use the [README first-run command](../README.md#first-run-a-small-python-draft). This disables search, not inference or dependency update checks.
