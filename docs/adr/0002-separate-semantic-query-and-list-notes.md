# Separate Semantic Query and Structured Note Listing Tools

We are renaming the vector search tool from `query` to `semantic_query` and introducing a separate `list_notes` tool for exact metadata filtering, date ranges, tag searches, and pattern matching. In an MCP server, generic tool names like `query` lead to LLM dispatch confusion where the model inadvertently calls simple filtering when exploratory topic search was intended. Recommending `semantic_query` by default accounts for conceptual queries across languages (English and Czech), while `list_notes` provides deterministic, alphabetical browsing with offset/limit pagination when specific dates, tags, or regex patterns are requested.

## Considered Options

- **Unified Query Tool with Mode Parameter**: Keeps a single tool entry point, but mixes dense vector search arguments with structured filter/regex/pagination schemas, complicating LLM parameter generation.
- **`query` (simple) and `semantic_query`**: Leaves simple search with the generic name `query`, risking LLM bias toward `query` even for topic exploration.
- **`semantic_query` and `list_notes`**: Explicitly separates exploratory semantic retrieval from structured metadata and pattern listing, guiding the LLM unambiguously via tool naming and descriptions.

## Consequences

- Existing MCP clients calling `query` must update to `semantic_query` or `list_notes`.
- `semantic_query` is documented and recommended as the default tool for topic and thought searches.
- `list_notes` handles date range (`from`/`to`), tag matching (case-insensitive AND across front matter and inline `#tag`s), plain text / regex pattern searches, and offset/limit pagination sorted alphabetically by relative path.
- When `from` or `to` is set, `list_notes` excludes notes with no parseable creation date (front matter `date`/`created`, a `YYYY-MM-DD` filename prefix, or the file modification time). To list undated notes, call `list_notes` without `from`/`to`.
