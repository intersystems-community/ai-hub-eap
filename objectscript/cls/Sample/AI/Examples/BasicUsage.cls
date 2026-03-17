/// Basic AI Usage Example
/// Demonstrates simple question-answering without tools
Class Sample.AI.Examples.BasicUsage Extends %RegisteredObject
{

/// Simple Q&A conversation example
ClassMethod SimpleQA() As %Status
{
    Try {
        Write !, "=== Simple Q&A Example ===", !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)
        Write "Provider created: OpenAI", !, !

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a helpful assistant."
        Write "Agent created with model: ", agent.Model, !, !

        Set session = agent.CreateSession()

        Set question = "What is the capital of France?"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !, !

        Set question = "What is its population?"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Multi-turn conversation example
ClassMethod Conversation() As %Status
{
    Try {
        Write !, "=== Multi-Turn Conversation Example ===", !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o-mini"
        Set agent.SystemPrompt = "You are a helpful coding tutor. Keep responses concise."

        Set session = agent.CreateSession()

        Set questions = ##class(%ListOfDataTypes).%New()
        Do questions.Insert("What is recursion in programming?")
        Do questions.Insert("Can you give me a simple example in Python?")
        Do questions.Insert("What are the risks of using recursion?")

        For i=1:1:questions.Count() {
            Set question = questions.GetAt(i)
            Write !, "Q", i, ": ", question, !
            Set response = agent.Chat(session, question)
            Write "A", i, ": ", response.Content, !, !
        }

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example with different providers
ClassMethod MultiProvider() As %Status
{
    Try {
        Write !, "=== Multi-Provider Example ===", !
        Write "This example shows using different AI providers", !, !

        Set openaiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If openaiKey '= "" {
            Write "--- OpenAI ---", !
            Set settings = {}
            Do settings.%Set("api_key", openaiKey)
            Set provider = ##class(%AI.Provider).Create("openai", settings)
            Set agent = ##class(%AI.Agent).%New(provider)
            Set agent.Model = "gpt-4o-mini"
            Set session = agent.CreateSession()
            Set response = agent.Chat(session, "Say hello in French")
            Write "Response: ", response.Content, !, !
        }

        Set anthropicKey = ##class(Sample.AI.Utils).GetAPIKey("anthropic")
        If anthropicKey '= "" {
            Write "--- Anthropic ---", !
            Set settings = {}
            Do settings.%Set("api_key", anthropicKey)
            Set provider = ##class(%AI.Provider).Create("anthropic", settings)
            Set agent = ##class(%AI.Agent).%New(provider)
            Set agent.Model = "claude-3-5-sonnet-20241022"
            Set session = agent.CreateSession()
            Set response = agent.Chat(session, "Say hello in Spanish")
            Write "Response: ", response.Content, !
        }

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

}
