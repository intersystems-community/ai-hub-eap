Include (%AI, %occStatus)

/// Example agent that uses the MCP server-everything toolset.
///
/// Demonstrates the full agent + MCP tool lifecycle:
///   - Subclassing %AI.Agent with auto-detected provider (reads API key from environment)
///   - Attaching an MCP ToolSet (server-everything via npx)
///   - Driving a multi-turn conversation loop
///
/// The provider is chosen automatically from whichever API key is present in the
/// environment (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, ...).
/// To override without restarting, set the process-private global:
///   Set ^||ENV("OPENAI_API_KEY") = "sk-..."
///
/// Quick start (Terminal session):
///   Set sc = ##class(Sample.AI.Agent.EverythingAgent).Demo()
///   Write $SYSTEM.Status.GetErrorText(sc)
Class Sample.AI.Agent.EverythingAgent Extends %AI.Agent
{

/// ToolSet that launches the MCP server-everything process
Parameter TOOLSETS = "Sample.AI.Tools.Everything";

/// System prompt
XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# MCP Test Assistant

You are a helpful assistant with access to a set of MCP tools from the
`server-everything` reference server. Use these tools to answer user requests.

## Available tools

- **echo** — repeat a message back verbatim
- **add** — add two numbers and return the result
- **longRunningOperation** — simulate a task that takes time (specify duration in seconds and number of progress steps)
- **getTinyImage** — retrieve a small test image
- **printEnv** — show current environment variables

When the user asks you to do something, use the appropriate tool rather than
answering from memory. Show the tool result in your response.
}

/// Default models per provider (used when no PROVIDER parameter is set)
Parameter MODELS = "openai=gpt-4o,anthropic=claude-haiku-4-5-20251001,gemini=gemini-2.0-flash,xai=grok-3";

/// Auto-detect provider from environment and create it.
/// Called by %AI.Agent.%Init() after the standard setup.
Method %OnInit() As %Status
{
    // Provider already set (e.g. passed to %New())
    If $ISOBJECT(..Provider) Return $$$OK

    Set key = ##class(Sample.AI.Utils).GetAPIKey("", .providerName)
    If key = "" {
        Return $$$ERROR($$$GeneralError, "No API key found. Set one of: OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, GROK_API_KEY")
    }

    Set ..Provider = ##class(%AI.Provider).Create(providerName, { "api_key": (key) })

    // Pick a default model for this provider
    For i=1:1:$LENGTH(..#MODELS, ",") {
        Set pair = $PIECE(..#MODELS, ",", i)
        If $PIECE(pair, "=", 1) = providerName {
            Set ..Model = $PIECE(pair, "=", 2)
            Quit
        }
    }

    Write "[EverythingAgent] Using provider: ", providerName, "  model: ", ..Model, !

    Return $$$OK
}

/// Run an interactive multi-turn conversation loop.
///
/// Type a message and press Enter. The agent will call MCP tools as needed
/// and print the response. Type "quit" or "exit" to end the session.
ClassMethod Demo() As %Status
{
    Write !, "=== EverythingAgent Demo ===", !
    Write "Type 'quit' or 'exit' to end the session.", !

    Set agent = ..%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) {
        Write !, "Failed to initialize agent: ", $SYSTEM.Status.GetErrorText(sc), !
        Return sc
    }
    Set session = agent.CreateSession()

    For {
        Write !, "You: "
        Read input

        Set input = $ZSTRIP(input, "<>W")
        If (input = "quit") || (input = "exit") {
            Write !, "Goodbye!", !
            Quit
        }
        If input = "" Continue

        Write !, "Agent: "
        Set response = agent.Chat(session, input)
        Do ##class(%AI.System).RenderMarkdown(response.Content)
        Write !

        // Show token usage after each turn
        Set stats = session.GetStats()
        Write "[tokens: prompt=", stats."total_prompt_tokens",
              " completion=", stats."total_completion_tokens",
              " tool_calls=", stats."total_tool_calls", "]", !
    }

    Return $$$OK
}

/// Non-interactive demo that exercises a fixed set of tool calls.
/// Useful for automated testing and bug reproduction.
ClassMethod DemoFixed() As %Status
{
    Write !, "=== EverythingAgent Fixed Demo ===", !

    Set agent = ..%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) {
        Write !, "Failed to initialize agent: ", $SYSTEM.Status.GetErrorText(sc), !
        Return sc
    }
    Set session = agent.CreateSession()

    Set prompts = $LISTBUILD(
        "Please echo the message: Hello from IRIS!",
        "What is 137 plus 456?",
        "Run a long running operation that takes 2 seconds with 4 progress steps.",
        "What tools do you have available?"
    )

    For i=1:1:$LISTLENGTH(prompts) {
        Set prompt = $LISTGET(prompts, i)
        Write !, "--- Turn ", i, " ---", !
        Write "You: ", prompt, !

        Set response = agent.Chat(session, prompt)
        Write "Agent: "
        Do ##class(%AI.System).RenderMarkdown(response.Content)
        Write !
    }

    Set stats = session.GetStats()
    Write !, "=== Session Stats ===", !
    Write "Turns      : ", $LISTLENGTH(prompts), !
    Write "Tool calls : ", stats."total_tool_calls", !
    Write "Prompt tok : ", stats."total_prompt_tokens", !
    Write "Completion : ", stats."total_completion_tokens", !

    Return $$$OK
}

}
