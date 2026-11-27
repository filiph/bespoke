# Obsidian Semantic Search

Semantic search and retrieval system for personal markdown vaults using local embedding models and MCP servers.

## Language

**Vault**:
The root directory containing a user's collection of markdown notes and media.
_Avoid_: Workspace, repository, folder

**Note**:
A single markdown file within the Vault, uniquely identified by its relative file path and creation/modification timestamps.
_Avoid_: Document, file, entry

**Text Segment**:
A sliding window slice of a Note's text content (typically 300 words with 100-word overlap), used as the discrete unit for vector embedding and relevance scoring.
_Avoid_: Chunk, slice, window

**Embedding Cache**:
A persistent local file in the user cache directory storing precomputed vector representations and note metadata to avoid recomputing unchanged notes across launches.
_Avoid_: Index database, vector store, state file

**Front Matter**:
An optional YAML metadata block at the beginning of a Note, delimited by `---`, containing structured properties such as tags or creation dates.
_Avoid_: Header, preamble, metadata block

**Tag**:
A case-insensitive identifier attached to a Note, either listed under the `tags` property in Front Matter or written inline as `#tag` within the Note body.
_Avoid_: Label, category, keyword

## Flagged ambiguities

- **Snippet vs Text Segment**: A Text Segment is the indexed sliding window of text within a Note, whereas a snippet is the formatted excerpt displayed in query results.

## Example dialogue

Dev: "When the server starts up, does it read the entire Vault?"
Domain Expert: "Yes, it scans the Vault for all Notes, compares their timestamps against the Embedding Cache, and only generates vectors for new or modified Text Segments."
Dev: "And during a query, what gets scored against the search phrase?"
Domain Expert: "Each Text Segment produces a similarity score, and the highest scoring segment determines the ranking of its parent Note."
