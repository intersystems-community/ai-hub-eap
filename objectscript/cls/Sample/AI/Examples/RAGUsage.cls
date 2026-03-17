/// RAG (Retrieval-Augmented Generation) Usage Examples
///
/// Demonstrates how to build knowledge bases and use them with AI agents.
///
/// Prerequisites:
///   - iris-llm library loaded
///   - OPENAI_API_KEY set (for OpenAI examples)
///     environment variable OR: Set ^||ENV("OPENAI_API_KEY") = "sk-..."
///
/// Usage:
///   Do ##class(Sample.AI.Examples.RAGUsage).FastEmbedDemo()
///   Do ##class(Sample.AI.Examples.RAGUsage).OpenAIEmbedDemo()
///   Do ##class(Sample.AI.Examples.RAGUsage).ReindexDemo()
Class Sample.AI.Examples.RAGUsage Extends %RegisteredObject
{

// --- FastEmbed + IRIS SQL Store --------------------------------------------------

/// Demonstrates a complete RAG pipeline using the built-in FastEmbed model
/// (AllMiniLML6V2, 384 dimensions) and an IRIS SQL table as the vector store.
///
/// No separate embedding API key is required - FastEmbed runs in-process.
ClassMethod FastEmbedDemo() As %Status
{
    Try {
        Write !, "=== FastEmbed RAG Demo ===", !

        // 1. Embedding model - local ONNX, no API key needed
        Write "Initialising FastEmbed (downloads model on first run)...", !
        Set emb = ##class(%AI.RAG.Embedding.FastEmbed).Create()
        Write "  Model: ", emb.ModelName, ", dims: ", emb.Dimensions, !, !

        // 2. Vector store - IRIS SQL table, dimensions must match the model
        Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set vs.TableName  = "Sample.RAGFastEmbed"
        Set vs.Dimensions = 384
        Set vs.ModelName  = "AllMiniLML6V2"
        Write "Building vector store (", vs.TableName, ")...", !
        $$$ThrowOnError(vs.Build())
        Write "  Vector store ready.", !, !

        // 3. Knowledge base - name becomes the tool name exposed to the LLM
        Set kb = ##class(%AI.RAG.KnowledgeBase).%New()
        Set kb.Name = "search_docs"
        Set kb.Description = "IRIS database documentation"
        Set kb.TopK = 3
        $$$ThrowOnError(kb.Build(emb, vs))
        Write "Knowledge base built.", !, !

        // 4. Index documents
        Write "Indexing documents...", !
        Set text = "IRIS is a high-performance multimodel database platform supporting SQL, objects, and documents."
        Set sc = kb.AddDocument(text, {"source": "intro.txt", "category": "overview"})
        $$$ThrowOnError(sc)

        Set text = "The %SQL.Statement class is used to prepare and execute dynamic SQL queries in IRIS."
        Set sc = kb.AddDocument(text, {"source": "sql.txt", "category": "guide"})
        $$$ThrowOnError(sc)

        Set text = "IRIS supports horizontal scaling via sharding and high availability via mirroring."
        Set sc = kb.AddDocument(text, {"source": "scaling.txt", "category": "architecture"})
        $$$ThrowOnError(sc)

        Set docs = [
            ["The Journal provides crash recovery by logging all database writes.", {"source": "journal.txt", "category": "architecture"}],
            ["Cache classes (now IRIS classes) use dot notation for property access.", {"source": "classes.txt", "category": "guide"}]
        ]
        Set chunks = kb.AddDocuments(docs)
        Write "  Total additional chunks indexed: ", chunks, !, !

        // 5. Wire to an agent (LLM call requires an API key)
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set provider = ##class(%AI.Provider).Create("openai", {"api_key": (apiKey)})
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a helpful IRIS database assistant. Use the search_docs tool to look up information before answering. Cite the source file when you use retrieved content."
        $$$ThrowOnError(kb.AddToAgent(agent))
        Write "Agent configured with search_docs tool.", !, !

        // 6. Ask questions - the agent retrieves relevant chunks automatically
        Set session = agent.CreateSession()

        Set questions = [
            "How do I execute a dynamic SQL query in IRIS?",
            "What options does IRIS have for high availability?"
        ]
        Set iter = questions.%GetIterator()
        While iter.%GetNext(.k, .q) {
            Write "Q: ", q, !
            Set response = agent.Chat(session, q)
            Write "A: ", response.Content, !, !
        }

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

// --- OpenAI Embeddings + Promoted Fields -----------------------------------------

/// Demonstrates using the OpenAI text-embedding-3-small model (1536 dimensions)
/// with promoted metadata fields that enable filtered similarity search.
ClassMethod OpenAIEmbedDemo() As %Status
{
    Try {
        Write !, "=== OpenAI Embeddings RAG Demo ===", !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        // 1. OpenAI embedding provider - derives HTTP client from the provider
        Set provider = ##class(%AI.Provider).Create("openai", {"api_key": (apiKey)})
        Set emb = ##class(%AI.RAG.Embedding.OpenAI).Create(provider)
        Write "  Model: ", emb.ModelName, ", dims: ", emb.Dimensions, !, !

        // 2. Vector store with promoted fields for indexed filtering
        Set fields = [
            {"name": "version",  "type": "varchar(20)", "description": "Product version tag (e.g. 2025.1)"},
            {"name": "category", "type": "varchar(64)", "description": "Document category"}
        ]
        Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set vs.TableName  = "Sample.RAGOpenAI"
        Set vs.Dimensions = 1536
        Set vs.ModelName  = "text-embedding-3-small"
        $$$ThrowOnError(vs.Build(fields))
        Write "Vector store ready with promoted fields: version, category", !, !

        // 3. Knowledge base
        Set kb = ##class(%AI.RAG.KnowledgeBase).%New()
        Set kb.Name = "search_docs"
        Set kb.Description = "IRIS release notes and documentation with version and category filters"
        Set kb.TopK = 5
        $$$ThrowOnError(kb.Build(emb, vs))

        // 4. Index documents that include the promoted field values in metadata
        Set docs = [
            ["IRIS 2025.1 introduces native VECTOR data type and VECTOR_COSINE() function.", {"source": "rn-2025.1.txt", "version": "2025.1", "category": "release-notes"}],
            ["IRIS 2025.1 adds %AI namespace with provider, agent, and RAG classes.",        {"source": "ai-2025.1.txt", "version": "2025.1", "category": "release-notes"}],
            ["IRIS 2024.3 introduced OAuth2 client support for REST services.",               {"source": "rn-2024.3.txt", "version": "2024.3", "category": "release-notes"}],
            ["The %AI.Agent class orchestrates multi-turn conversations with tool use.",      {"source": "ai-guide.txt",  "version": "2025.1", "category": "guide"}]
        ]
        Set chunks = kb.AddDocuments(docs)
        Write "Documents indexed: "_chunks_" chunks.", !, !

        // 5. Agent
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a documentation assistant for InterSystems IRIS. Always search before answering. Mention the source and version when relevant."
        $$$ThrowOnError(kb.AddToAgent(agent))

        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "What AI features were added in IRIS 2025.1?")
        Write "A: ", response.Content, !

        // Diagnostic: show tool call count
        Set stats = session.GetStats()
        Write "(Tool calls made: "_stats.%Get("total_tool_calls", 0)_")", !

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

// --- Re-indexing a Changed Document ----------------------------------------------

/// Demonstrates ReindexDocument() - atomic replacement of a document's chunks.
/// Old chunks for the source are deleted before new ones are inserted,
/// so stale content never accumulates in the vector store.
ClassMethod ReindexDemo() As %Status
{
    Try {
        Write !, "=== ReindexDocument Demo ===", !

        // Use FastEmbed so no API key is needed for embeddings
        Set emb = ##class(%AI.RAG.Embedding.FastEmbed).Create()

        Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set vs.TableName  = "Sample.RAGReindex"
        Set vs.Dimensions = 384
        Set vs.ModelName  = "AllMiniLML6V2"
        $$$ThrowOnError(vs.Build())

        Set kb = ##class(%AI.RAG.KnowledgeBase).%New("search_docs", "Mutable document store demo")
        $$$ThrowOnError(kb.Build(emb, vs))

        // Index initial version
        Set sc = kb.AddDocument("IRIS version 1.0 - initial release with basic SQL support.", {"source": "release.txt"})
        $$$ThrowOnError(sc)
        Write "Initial document indexed.", !

        // Simulate a document update - replaces all chunks for release.txt
        Set newText = "IRIS version 2.0 - added vector search, AI integration, and native JSON support."
        Set chunks = kb.ReindexDocument("release.txt", newText, {"category": "release-notes"})
        Write "Document re-indexed with ", chunks, " chunks.", !, !

        // Connect agent and verify the updated content is retrieved
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set provider = ##class(%AI.Provider).Create("openai", {"api_key": (apiKey)})
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a documentation assistant. Always use search_docs first."
        $$$ThrowOnError(kb.AddToAgent(agent))

        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "What's new in the latest IRIS release?")
        Write "A: ", response.Content, !

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

}
