/// Example custom agent with declarative configuration.
/// Demonstrates using Parameters and XData blocks to configure an agent specialized for file operations.
Class Sample.AI.Agent.FileSystemAgent Extends %AI.Agent
{

/// Provider to use
Parameter PROVIDER = "vertex";

/// Provider configuration
/// service_account_path can use @{env.VERTEX_SA_PATH} or @{config.VertexSAPath} to avoid hardcoding
Parameter PROVIDERCONFIG = "{ ""project_id"": ""my-gcp-project"", ""region"": ""us-east5"", ""service_account_path"": ""@{env.VERTEX_SA_PATH}"" }";

/// Model to use (Claude 4.5)
Parameter MODEL = "claude-sonnet-4-5@20250929";

/// API Key (reads from ANTHROPIC_API_KEY environment variable if not set)
Parameter APIKEY;

/// ToolSets to attach (comma-separated list)
Parameter TOOLSETS = "%AI.Tools.FileSystem,%AI.Tools.BMI";

/// System Instructions in Markdown format
XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# File System Assistant

You are a helpful AI assistant specialized in file system operations.

## Available Tools
- **File System Operations**: Read files and list directories
- **BMI Calculator**: Calculate Body Mass Index

## Guidelines
- Always explain what you're doing when accessing files
- Be helpful and concise
- Use markdown formatting in your responses
- When listing directory contents, present them in an organized format
}

/// Custom initialization hook (optional)
/// This is called after %Init() completes the standard setup
Method %OnInit() As %Status
{
    // Example: Could set additional properties, configure policies, etc.
    // Set ..Temperature = 0.9

    Return $$$OK
}

/// Example usage with blocking Chat
ClassMethod DemoChat() As %Status
{
    Write !, "=== Blocking Chat Demo ===", !

    // Create and initialise agent
    Set agent = ..%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) Return sc

    Write "Provider: ", agent.Provider.Name, !
    Write "Model: ", agent.Model, !

    // Create chat session
    Set session = agent.CreateSession()

    // Simple interaction
    Write !, "Asking about available tools...", !
    Set response = agent.Chat(session, "What tools do you have access to?")
    Write !, "Response:", !
    Do ##class(%AI.System).PrettyPrint(response.Content)
    Write !

    // Interaction with tool use
    Write !, !, "Asking to list files...", !
    Set response = agent.Chat(session, "List the files in the current directory")
    Write !, "Response:", !
    Do ##class(%AI.System).PrettyPrint(response.Content)
    Write !

    // Show stats
    Set stats = session.GetStats()
    Write !, "Session Stats:", !
    Write "  Interactions: ", stats."total_interactions", !
    Write "  Tool Calls: ", stats."total_tool_calls", !
    Write "  Total Tokens: ", (stats."total_prompt_tokens" + stats."total_completion_tokens"), !

    Return $$$OK
}

/// Example usage with streaming
ClassMethod DemoStream() As %Status
{
    Write !, "=== Streaming Chat Demo ===", !

    // Create agent
    Set agent = ..%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) Return sc

    // Create chat session
    Set session = agent.CreateSession()

    // Stream interaction with markdown rendering
    Write !, "Streaming response...", !

    // Use StreamRenderer for proper markdown rendering
    Set renderer = ##class(%AI.System.StreamRenderer).%New()
    Set renderer.ThinkingPrompt = ""
    Set response = agent.StreamChat(session, "Tell me about file system operations", renderer, "OnChunk")

    // Flush any remaining buffered content
    Do renderer.Flush()

    Write !, !, "Final response length: ", $LENGTH(response.Content), " chars", !

    Return $$$OK
}

/// Example usage with multi-modal content
ClassMethod DemoMultiModal() As %Status
{
    Write !, "=== Multi-Modal Demo ===", !

    // Create agent
    Set agent = ..%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) Return sc

    // Create chat session
    Set session = agent.CreateSession()

    // Build multi-modal content (text + image)
    Set content = []
    Do content.%Push({
        "type": "text",
        "text": "What do you see in this image?"
    })
    Do content.%Push({
        "type": "image_url",
        "image_url": {
            "url": "https://example.com/image.jpg"
        }
    })

    // Send multi-modal content
    Set response = agent.ChatWithContent(session, content)
    Write !, "Response:", !
    Do ##class(%AI.System).PrettyPrint(response.Content)
    Write !

    Return $$$OK
}

/// Run all demos
ClassMethod Demo() As %Status
{
    Set sc = ..DemoChat()
    If $$$ISERR(sc) Return sc

    Set sc = ..DemoStream()
    If $$$ISERR(sc) Return sc

    Return $$$OK
}

}
