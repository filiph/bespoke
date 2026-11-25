# Migrate from GloVe to EmbeddingGemma 2 with Persistent Cache

We are replacing static GloVe word-averaging embeddings with local Ollama `embeddinggemma-2` embeddings in `filip_mcp` and introducing a persistent on-disk cache in the user cache directory. GloVe lacked deep semantic and contextual understanding for long notes, while `embeddinggemma-2` provides state-of-the-art dense semantic text representations for paragraphs and full documents. To prevent multi-minute indexing delays on vault launch across 5,000+ notes, embeddings and file modification timestamps are persisted to disk and incrementally refreshed in batches.

## Considered Options

- **GloVe 100d**: Fast CPU-only word vector averaging, but poor semantic accuracy for complex queries and phrases.
- **Pure In-Memory EmbeddingGemma 2**: High semantic accuracy, but unacceptable 3–10 minute startup latency on every tool launch.
- **EmbeddingGemma 2 with Disk Cache**: Optimal balance of deep semantic accuracy and near-instantaneous startup after initial indexing.

## Consequences

- Requires local Ollama running with `embeddinggemma-2` installed.
- GloVe download scripts, word vector serialization, and text files are removed completely.
- Text segments default to 300 words with 100-word overlap, matching `embeddinggemma-2` passage strengths.
- Both the MCP server (`filip_mcp.dart`) and the CLI search tool (`filip_search.dart`) share vault indexing, caching, and vector search logic.
