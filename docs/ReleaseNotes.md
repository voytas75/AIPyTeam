# AI Python Team with RAG - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.1.0] — beta

- Azure defaults to Responses for fresh projects; omitted streaming is false. Explicit ChatCompletions/local defaults and saved/legacy settings remain compatible.
- Explicit output/time bounds are forwarded, Responses requests use UTF8 JSON, `store=false`, completed-only text admission and in-memory Windows DPAPI decoding of the shared PSAOAI Process key. No protocol fallback or retry.
- Fail-stop workflow preserves the last-good draft and persists Completed/Partial/Failed/legacy NotRecorded with safe stage/error fields. Failed saves never announce completion.
- Section-aware UTF8 Python export retains production/helpers, excludes Usage and explicitly delimited development tests, and rejects ambiguous content without overwriting.
- Native 5.1/7 offline source-bound tests cover defaults, transport/budgets, local startup, export, full fixture workflow and recovery. Actual exported Python is syntax-parsed without execution. Release preparation changes only version/help/docs, not provider APIs or defaults.
- Limitations: beta; no fresh live qualification of release bytes, generated-code execution, unguarded dependency bootstrap, interactive UI or RAG acceptance. Responses streaming/tools/conversation chaining are unsupported. Historical full120 transport success preceded export/fail-stop repairs and does not qualify current bytes.
- Publication is manual by the owner. Version 0.1.0 is the selected release version, not a claim of Gallery availability or an invented publication date.

## Historical release archive

## [0.0.3] - 2024.07.25

- Added logo.

## [0.0.2] - 2024.07.25

- Added `Python` to the project description.
- Made minor adjustments and improvements.

## [0.0.1] - 2024.07.24

- Initializing.
