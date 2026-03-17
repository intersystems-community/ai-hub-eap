# InterSystems AI Hub - ObjectScript SDK User Guide

> [!IMPORTANT]
> Please note this is prerelease software, and any APIs and functionality described in this document is subject to change without prior notice before the initial GA release of the AI Hub.

## Overview

InterSystems AI Hub is a comprehensive framework for building AI-powered applications in InterSystems IRIS using ObjectScript. It provides a native, object-oriented API for interacting with Large Language Models (LLMs) and building agentic applications with tool calling capabilities.

### What is the InterSystems AI Hub?

The AI Hub bridges the gap between ObjectScript applications and modern LLM providers. It allows you to:

- **Integrate multiple LLM providers** - OpenAI, Anthropic, Google (Gemini/Vertex), AWS Bedrock, Meta, xAI Grok, NVIDIA NIM
- **Build AI agents** - Create autonomous agents that can use tools to accomplish complex tasks
- **Define tools in ObjectScript** - Expose ObjectScript methods, SQL queries, and external services as tools
- **Implement governance** - Control tool execution with authorization and audit policies
- **Work with multi-modal content** - Process and generate text and images
- **Stream responses** - Provide real-time feedback to users
- **Connect to external tools** - Integrate Model Context Protocol (MCP) servers

### Architecture

```
┌─────────────────────────────────────────────────┐
│         Your Agentic Application                │
│  (Custom ObjectScript classes and logic)        │
└──────────────────┬──────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────┐
│            %AI.Agent (Execution Engine)         │
│  - Manages conversation flow                    │
│  - Coordinates between LLM and tools            │
│  - Enforces policies                            │
└────┬───────────────────────┬────────────────────┘
     │                       │
     ↓                       ↓
┌──────────────┐      ┌─────────────────────────┐
│ %AI.Provider │      │   %AI.ToolMgr           │
│ - LLM APIs   │      │   - Tool discovery      │
│ - Streaming  │      │   - Tool execution      │
│              │      │   - Policy enforcement  │
└──────────────┘      └──────────┬──────────────┘
                                 │
                                 ↓
                      ┌─────────────────────────┐
                      │   %AI.ToolSet           │
                      │   - XML-based tools     │
                      │   - MCP integration     │
                      │   - Tool composition    │
                      └─────────────────────────┘
```

## Getting Started: API Key Setup

Before using any LLMs, you need to configure API keys for your LLM provider. 
The AI Hub uses the IRIS Wallet to store credentials, through a new facility called the IRIS Config Store.

:warning: The IRIS Config Store is still a work in progress. In the current version of the AI Hub, you can still use simple environment variables to pass API keys.

### Current method: Environment Variables (Requires IRIS Restart)

The standard approach is to set environment variables:

**On Linux/macOS:**
```bash
export OPENAI_API_KEY="sk-..."
# OR
export ANTHROPIC_API_KEY="sk-ant-..."

# Then restart IRIS
iris stop <instance>
iris start <instance>
```

**On Windows PowerShell:**
```powershell
$env:OPENAI_API_KEY = "sk-..."
# OR
$env:ANTHROPIC_API_KEY = "sk-ant-..."

# Then restart IRIS
iris stop <instance>
iris start <instance>
```

**Important:** IRIS must be restarted after setting environment variables for them to be visible to the IRIS process.

### Verifying API Key Setup

```objectscript
// Check environment variable
USER> Write $System.Util.GetEnviron("OPENAI_API_KEY")

// Quick test
USER> Set provider = ##class(%AI.Provider).Create("openai", {"api_key": "sk-..."})
USER> Write provider.ProviderName()
openai
```

## Core Components

### %AI.Provider - LLM Provider Interface

The `%AI.Provider` class represents a connection to an LLM provider. It handles API communication, model selection, and response parsing.

**Creating a Provider:**

```objectscript
ClassMethod Create(name As %String, settings As %DynamicObject) As %AI.Provider
```

**Supported Providers:**

| Provider | Name | Key Settings |
|----------|------|--------------|
| OpenAI | `"openai"` | `api_key`, `organization` |
| Anthropic | `"anthropic"` | `api_key` |
| Google Gemini | `"gemini"` | `api_key` |
| Google Vertex AI | `"vertex"` | `project_id`, `region`, `service_account_path` |
| AWS Bedrock | `"bedrock"` | `region` (SigV4) or `bearer_token` + `region` |
| Meta Llama | `"meta"` | `api_key` |
| xAI Grok | `"grok"` | `api_key` |
| NVIDIA NIM | `"nim"` | `base_url` |

**Example Usage:**

```objectscript
// OpenAI
Set provider = ##class(%AI.Provider).Create("openai", {
    "api_key": "sk-..."
})

// Anthropic
Set provider = ##class(%AI.Provider).Create("anthropic", {
    "api_key": "sk-ant-..."
})

// AWS Bedrock — SigV4 (standard AWS credential chain)
// Credentials come from env vars (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY),
// IAM role, AWS profile, or SSO — whichever the SDK resolves first.
Set provider = ##class(%AI.Provider).Create("bedrock", {
    "region": "us-east-1"
})

// AWS Bedrock — Bearer token (long-lived API key from the Bedrock console)
// Supply the token explicitly in config:
Set provider = ##class(%AI.Provider).Create("bedrock", {
    "region": "us-east-1",
    "bearer_token": "..."
})
// Or set the environment variable AWS_BEARER_TOKEN_BEDROCK and omit bearer_token:
Set provider = ##class(%AI.Provider).Create("bedrock", {
    "region": "us-east-1"
})
// Note: bearer token mode requires cross-region inference profile IDs
// (e.g. "us.anthropic.claude-3-5-sonnet-20241022-v2:0") rather than
// raw model IDs.  ListModels() is not supported in bearer token mode.

// List available models
Set models = provider.ListModels()
Set iter = models.%GetIterator()
While iter.%GetNext(.key, .model) {
    Write model.id, " - ", model.name, !
}
```

**Checking Capabilities:**

```objectscript
Set provider = ##class(%AI.Provider).Create("anthropic", {"api_key": apiKey})

// Get all capabilities
Set caps = provider.GetCapabilities()
Write "Provider capabilities:", !
For i=0:1:caps.%Size()-1 {
    Write "  - ", caps.%Get(i), !
}

// Check specific capability using Parameters (recommended)
If provider.HasCapability(provider.#CAPABILITYPROMPTCACHING) {
    Write "Provider supports prompt caching!", !
}

If provider.HasCapability(provider.#CAPABILITYTOOLCALLING) {
    Write "Provider supports tool calling!", !
}

// Or use string directly
If provider.HasCapability("StreamingResponse") {
    Write "Provider supports streaming!", !
}
```

**Available Capabilities (Parameters):**

| Parameter | Value | Description | Providers |
|-----------|-------|-------------|-----------|
| `CAPABILITYTEXTCOMPLETION` | `"TextCompletion"` | Legacy completion API | OpenAI |
| `CAPABILITYCHATCOMPLETION` | `"ChatCompletion"` | Chat/messages API | All |
| `CAPABILITYIMAGEGENERATION` | `"ImageGeneration"` | Generate images | OpenAI |
| `CAPABILITYIMAGEUNDERSTANDING` | `"ImageUnderstanding"` | Vision/multimodal | Anthropic, OpenAI, Gemini, Bedrock, Vertex |
| `CAPABILITYTOOLCALLING` | `"ToolCalling"` | Function/tool calling | Anthropic, OpenAI, Gemini, Bedrock, Vertex |
| `CAPABILITYSTREAMING` | `"StreamingResponse"` | Streaming responses | All |
| `CAPABILITYPROMPTCACHING` | `"PromptCaching"` | Context caching | Anthropic, OpenAI, Gemini, Bedrock (SigV4 only), Vertex |

### %AI.Agent - Execution Engine

The `%AI.Agent` class is the core execution engine. It manages the interaction between the LLM, tools, and policies. This is what orchestrates multi-turn conversations with tool calling.

**Key Responsibilities:**
- Execute LLM requests with tool schemas
- Handle tool call responses from the LLM
- Invoke tools through the ToolManager
- Apply authorization and audit policies
- Manage streaming and feedback

**Properties:**

```objectscript
Property Provider As %AI.Provider       // LLM provider
Property Model As %String                // Model name override
Property SystemPrompt As %String         // System instructions
Property Temperature As %Float           // Randomness (0.0-2.0)
Property ToolManager As %AI.ToolMgr      // Tool and policy manager
```

**Creating an Agent:**

```objectscript
Set provider = ##class(%AI.Provider).Create("openai", {"api_key": apiKey})
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "gpt-4"
Set agent.SystemPrompt = "You are a helpful assistant."
Set agent.Temperature = 0.7
```

**Model Settings Configuration:**

You can configure LLM parameters when creating a session using a JSON configuration object:

```objectscript
// Create session with model settings
Set config = {
    "max_iterations": 10,
    "temperature": 0.7,          // Randomness/creativity (0.0-2.0)
    "max_tokens": 1000,          // Maximum response length
    "top_p": 0.9,                // Nucleus sampling (0.0-1.0)
    "presence_penalty": 0.1,     // Penalize new topics (-2.0 to 2.0)
    "frequency_penalty": 0.1,    // Penalize repetition (-2.0 to 2.0)
    "stop_sequences": ["END"],   // Stop generation at these strings
    "cache": {
        "enabled": (1),
        "cache_system_prompt": (1),
        "cache_tool_definitions": (1)
    }
}

Set session = agent.CreateSession(config)
```

**Model Settings Guidelines:**

| Parameter | Range | Best For |
|-----------|-------|----------|
| **temperature: 0.0-0.3** | Low | Factual Q&A, data extraction, consistent outputs |
| **temperature: 0.4-0.7** | Medium | General purpose (default: 0.7) |
| **temperature: 0.8-1.2** | High | Creative writing, brainstorming |
| **temperature: 1.3-2.0** | Very High | Experimental, may be incoherent |
| **max_tokens** | > 0 | Limits response length, controls costs |
| **top_p: 0.8-1.0** | High | More diverse responses |
| **top_p: 0.1-0.7** | Low | More focused, deterministic |
| **presence_penalty** | -2.0 to 2.0 | Positive = encourage new topics |
| **frequency_penalty** | -2.0 to 2.0 | Positive = discourage repetition |

**Examples:**

```objectscript
// Factual mode - consistent, deterministic responses
Set factualConfig = {
    "temperature": 0.2,
    "max_tokens": 200,
    "top_p": 0.8
}

// Creative mode - varied, imaginative responses
Set creativeConfig = {
    "temperature": 1.2,
    "max_tokens": 1000,
    "presence_penalty": 0.6,
    "frequency_penalty": 0.3
}

// Concise mode - short, focused responses
Set conciseConfig = {
    "temperature": 0.5,
    "max_tokens": 100,
    "stop_sequences": ["###", "END"]
}
```

**Declarative Agent Configuration:**

For easier agent creation, you can subclass `%AI.Agent` and use Parameters and XData blocks for declarative configuration:

```objectscript
Class Sample.AI.Agent.FileSystemAgent Extends %AI.Agent
{
  /// Provider to use
  Parameter PROVIDER = "anthropic";

  /// Model to use
  Parameter MODEL = "claude-sonnet-4-5@20250929";

  /// API Key (reads from ANTHROPIC_API_KEY if not set)
  Parameter APIKEY;

  /// Comma-separated list of ToolSets
  Parameter TOOLSETS = "%AI.Tools.FileSystem,%AI.Tools.BMI";

  /// System Instructions in Markdown
  XData INSTRUCTIONS [ MimeType = text/markdown ]
  {
# File System Assistant

You are a helpful AI assistant specialized in file system operations.

## Available Tools
- File System Operations
- BMI Calculator
  }

  /// Custom initialization hook (optional)
  Method %OnInit() As %Status
  {
    // Configure additional properties if needed
    Return $$$OK
  }
}
```

Then create the agent without passing a provider:

```objectscript
Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
// Provider, model, system prompt, and toolsets are all configured!
```

**Supported Configuration Parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `PROVIDER` | Provider name | `"anthropic"`, `"openai"`, `"vertex"` |
| `MODEL` | Model ID | `"claude-sonnet-4-5@20250929"` |
| `APIKEY` | API key (for simple providers) | Read from environment if empty |
| `PROVIDERCONFIG` | JSON config (for complex providers) | `{"region": "us-east-1", ...}` |
| `TOOLSETS` | Comma-separated ToolSet classes | `"%AI.Tools.FileSystem,%AI.Tools.SQL"` |

**Configuration Priority:**

1. Runtime assignment (highest): `Set agent.Model = "..."`
2. Property `InitialExpression`
3. Parameter value
4. XData block content

**Using Declarative Agents:**

The `Sample.AI.Agent.FileSystemAgent` class demonstrates the three main interaction patterns:

1. **Blocking Chat** - Synchronous request/response:

```objectscript
ClassMethod DemoChat() As %Status
{
    Write !, "=== Blocking Chat Demo ===", !

    // Create agent - provider created from PROVIDER parameter
    Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()

    Write "Provider: ", agent.Provider.ProviderName(), !
    Write "Model: ", agent.Model, !

    // Create chat session
    Set session = agent.CreateSession()

    // Simple interaction
    Write !, "Asking about available tools...", !
    Set response = agent.Chat(session, "What tools do you have access to?")
    Write !, "Response: ", response.Content, !

    // Interaction with tool use
    Write !, !, "Asking to list files...", !
    Set response = agent.Chat(session, "List the files in the current directory")
    Write !, "Response: ", response.Content, !

    // Show stats
    Set stats = session.GetStats()
    Write !, "Session Stats:", !
    Write "  Interactions: ", stats."total_interactions", !
    Write "  Tool Calls: ", stats."total_tool_calls", !
    Write "  Total Tokens: ", (stats."total_prompt_tokens" + stats."total_completion_tokens"), !

    Return $$$OK
}
```

2. **Streaming Chat** - Real-time response chunks:

```objectscript
ClassMethod DemoStream() As %Status
{
    Write !, "=== Streaming Chat Demo ===", !

    // Create agent
    Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()

    // Create chat session
    Set session = agent.CreateSession()

    // Stream interaction with callback
    Write !, "Streaming response...", !
    Set callback = ##class(Sample.AI.Agent.StreamCallback).%New()
    Set response = agent.StreamChat(session, "Tell me about file system operations", callback, "OnChunk")

    Write !, !, "Final response length: ", $LENGTH(response.Content), " chars", !

    Return $$$OK
}

/// Simple streaming callback for demo
Class Sample.AI.Agent.StreamCallback Extends %RegisteredObject
{
    Method OnChunk(chunk As %String)
    {
        Write chunk
    }
}
```

3. **Multi-Modal Content** - Text with images or other media:

```objectscript
ClassMethod DemoMultiModal() As %Status
{
    Write !, "=== Multi-Modal Demo ===", !

    // Create agent
    Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()

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
    Write !, "Response: ", response.Content, !

    Return $$$OK
}
```

**Running the Demos:**

```objectscript
// Run individual demos
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoChat()
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoStream()
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoMultiModal()

// Run all demos
Do ##class(Sample.AI.Agent.FileSystemAgent).Demo()
```

**Core Methods:**

```objectscript
// Blocking interaction
Method Chat(
    session As %AI.Agent.Session,
    input As %String,
    feedback As %RegisteredObject = ""
) As %AI.LLM.Response

// Streaming interaction
Method StreamChat(
    session As %AI.Agent.Session,
    input As %String,
    callbackObj As %RegisteredObject,
    callbackMethod As %String
) As %AI.LLM.Response

// Multi-modal interaction
Method ChatWithContent(
    session As %AI.Agent.Session,
    content As %DynamicArray,
    feedback As %RegisteredObject = ""
) As %AI.LLM.Response
```

### %AI.Agent.Session - Session Management

The `%AI.Agent.Session` class manages conversation state, including message history and statistics. Sessions are created from an agent and contain the conversation context.

**Creating a Session:**

```objectscript
// Create agent first
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "gpt-4"
Set agent.SystemPrompt = "You are a helpful assistant."

// Create session from agent - inherits model, prompt, and tools
Set session = agent.CreateSession()

// Optional: Pass configuration for caching, max iterations, model settings, etc.
Set config = {
    "max_iterations": 10,
    "temperature": 0.7,
    "max_tokens": 1000,
    "top_p": 0.9,
    "cache": {
        "enabled": (1),
        "cache_system_prompt": (1),
        "cache_tool_definitions": (1)
    }
}
Set session = agent.CreateSession(config)
```

**Advanced: Direct Session Creation**

For advanced use cases, you can create sessions directly:

```objectscript
Set session = ##class(%AI.Agent.Session).Create(
    provider,                   // %AI.Provider instance
    "gpt-4",                    // model
    "You are helpful.",         // system prompt
    toolsJson,                  // tool schemas from agent.ToolManager.%Discover()
    config                      // optional config object
)
```

**Session Statistics:**

```objectscript
Set stats = session.GetStats()

Write "Interactions: ", stats."total_interactions", !
Write "Prompt tokens: ", stats."total_prompt_tokens", !
Write "Completion tokens: ", stats."total_completion_tokens", !
Write "Tool calls: ", stats."total_tool_calls", !
Write "LLM time: ", stats."total_llm_duration_ms", "ms", !
```

### %AI.ToolMgr - Tool Registry & Policy Manager

The `%AI.ToolMgr` manages tool registration, discovery, and execution. It also enforces authorization and audit policies.

**Tool Discovery:**

```objectscript
// Get all registered tools as STP-format JSON
Set toolsJson = agent.ToolManager.%Discover()

// Returns array like:
// [
//   {"name": "get_weather", "description": "...", "parameters": {...}},
//   {"name": "run_sql", "description": "...", "parameters": {...}}
// ]
```

**Adding Tools:**

```objectscript
// Add a tool by URI (factory-based, recommended)
Do agent.ToolManager.AddTool("rust:filesystem")
Do agent.ToolManager.AddTool("iris:%AI.Tools.SQL")
Do agent.ToolManager.AddTool("mcp:stdio:npx @modelcontextprotocol/server-git")

// Add a tool with configuration
Do agent.ToolManager.AddTool({"type":"rust:filesystem","config":{"base_dir":"/data"}})

// Add a tool instance directly
Set myTools = ##class(MyApp.Tools).%New()
Do agent.ToolManager.AddTool(myTools)
```

**Setting Policies:**

```objectscript
// Authorization policy
Do agent.ToolManager.SetAuthPolicy(##class(%AI.Policy.InteractiveAuth).%New())

// Audit policy
Do agent.ToolManager.SetAuditPolicy(##class(%AI.Policy.ConsoleAudit).%New())
```

### %AI.LLM.Response - Response Object

Represents a response from the LLM.

**Properties:**

```objectscript
Property Content As %String         // The text response
Property ToolCalls As %DynamicArray // Tool calls requested
Property Usage As %DynamicObject    // Token usage stats
```

**Usage:**

```objectscript
Set response = agent.Chat(session, "What is 2+2?")
Write "Response: ", response.Content, !
Write "Tokens used: ", response.Usage."total_tokens", !

// Check for tool calls
If response.ToolCalls.%Size() > 0 {
    Write "Model requested tools:", !
    Set iter = response.ToolCalls.%GetIterator()
    While iter.%GetNext(.key, .call) {
        Write "  - ", call.name, "(", call.arguments, ")", !
    }
}
```

## Building Tools

Tools are ObjectScript methods that the AI can invoke. There are several ways to create tools.

### Method 1: Simple ToolSet with Inline Tools

The simplest approach is to extend `%AI.ToolSet` and define tools in an XData block.

```objectscript
Class MyApp.SimpleTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="SimpleTools">
            <Description>Basic application tools</Description>

            <Tool Name="GetTime" Method="GetTime">
                <Description>Get the current server time.</Description>
            </Tool>

            <Tool Name="GetUserCount" Method="GetUserCount">
                <Description>Get the total number of users.</Description>
            </Tool>
        </ToolSet>
    }

    /// Get current time
    Method GetTime() As %String
    {
        Return $ZDATETIME($HOROLOG, 3)
    }

    /// Count users
    Method GetUserCount() As %Integer
    {
        &sql(SELECT COUNT(*) INTO :count FROM Security.Users)
        Return count
    }
}
```

**Using the ToolSet:**

```objectscript
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "gpt-4"
Do agent.UseToolSet("MyApp.SimpleTools")

// Create session from agent
Set session = agent.CreateSession()

Set response = agent.Chat(session, "What time is it?")
// AI will call GetTime() automatically
```

### Method 2: Tools with Parameters

Tools can accept parameters with JSON Schema definitions.

```objectscript
Class MyApp.Calculator Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="Calculator">
            <Tool Name="Add" Method="Add">
                <Description>Add two numbers together.</Description>
                <Parameters>
                    <Parameter Name="a" Type="number" Required="true">
                        <Description>First number</Description>
                    </Parameter>
                    <Parameter Name="b" Type="number" Required="true">
                        <Description>Second number</Description>
                    </Parameter>
                </Parameters>
            </Tool>
        </ToolSet>
    }

    Method Add(args As %DynamicObject) As %Float
    {
        Set a = args.a
        Set b = args.b
        Return a + b
    }
}
```

**Note:** Tools with parameters receive a `%DynamicObject` containing the arguments.

### Method 3: Wrapping Existing Classes

You can expose existing ObjectScript classes as tools.

```objectscript
Class MyApp.DataTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="DataTools">
            <Tool Name="SearchPatients" Method="SearchPatients">
                <Description>Search for patients by name.</Description>
                <Parameters>
                    <Parameter Name="name" Type="string" Required="true">
                        <Description>Patient name to search for</Description>
                    </Parameter>
                </Parameters>
            </Tool>
        </ToolSet>
    }

    Method SearchPatients(args As %DynamicObject) As %String
    {
        Set name = args.name
        Set results = ##class(MyApp.Patient).SearchByName(name)

        // Format results as JSON
        Set output = []
        While results.%Next() {
            Do output.%Push({
                "id": (results.ID),
                "name": (results.Name),
                "dob": (results.DOB)
            })
        }

        Return output.%ToJSON()
    }
}
```

### Method 4: Use Built-in Tools

The framework provides built-in tools including a generic `%AI.Tools.SQL`.

**Using SQL Tools:**

```objectscript
// Include SQL tools in your ToolSet
Class MyApp.MyTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="MyTools">
            <!-- Include SQL tools with read-only requirement -->
            <Include Class="%AI.Tools.SQL">
                <Requirement Name="ReadOnly" Value="1"/>
            </Include>
        </ToolSet>
    }
}
```

Or use directly:

```objectscript
Do agent.UseToolSet("%AI.Tools.SQL")
```

## Building ToolSets

ToolSets are collections of tools organized by domain or functionality. They support composition, filtering, and integration with external services.

### ToolSet Structure

```objectscript
Class MyApp.CompleteExample Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="CompleteExample">
            <Description>Demonstrates all ToolSet features.</Description>

            <!-- 1. Inline Tools -->
            <Tool Name="Echo" Method="Echo">
                <Description>Echo back the input.</Description>
                <Parameters>
                    <Parameter Name="text" Type="string" Required="true">
                        <Description>Text to echo</Description>
                    </Parameter>
                </Parameters>
            </Tool>

            <!-- 2. Include Other ToolSets -->
            <Include Class="%AI.Tools.SQL">
                <Requirement Name="ReadOnly" Value="1"/>
            </Include>

            <!-- 3. Include with Filtering -->
            <Include Class="%AI.Tools.FileSystem">
                <Filter>
                    <Include Name="read_file"/>
                    <Include Name="list_directory"/>
                    <Exclude Name="delete_file"/>
                    <Exclude Name="write_file"/>
                </Filter>
            </Include>

            <!-- 4. MCP Server (External Tools) -->
            <MCP Name="FileServer">
                <Stdio Executable="/usr/local/bin/mcp-server-filesystem">
                    <Env Name="ALLOWED_PATHS" Value="/data,/tmp"/>
                </Stdio>
            </MCP>
        </ToolSet>
    }

    Method Echo(args As %DynamicObject) As %String
    {
        Return "Echo: " _ args.text
    }
}
```

### Including Other ToolSets

Compose ToolSets by including other ToolSets:

```xml
<Include Class="%AI.Tools.SQL">
    <Requirement Name="ReadOnly" Value="1"/>
    <Requirement Name="Role" Value="%All"/>
</Include>
```

**Requirements** are metadata passed to the included ToolSet. The included ToolSet can use these to customize behavior.

### Filtering Tools

Control which tools from an included ToolSet are exposed:

```xml
<Include Class="%AI.Tools.FileSystem">
    <Filter>
        <!-- Only include specific tools -->
        <Include Name="read_file"/>
        <Include Name="list_directory"/>

        <!-- Explicitly exclude dangerous tools -->
        <Exclude Name="delete_file"/>
        <Exclude Name="write_file"/>
    </Filter>
</Include>
```

### MCP Server Integration

:warning: In a forthcoming update, this capability will switch to use stored MCP configurations using the IRIS Config Store.

Connect to external Model Context Protocol servers:

**Stdio MCP Server:**

```xml
<MCP Name="FileServer">
    <Stdio Executable="/usr/local/bin/mcp-server-filesystem">
        <Env Name="ALLOWED_PATHS" Value="/data,/tmp"/>
        <Env Name="LOG_LEVEL" Value="info"/>
    </Stdio>
</MCP>
```

**Remote MCP Server (WebSocket):**

```xml
<MCP Name="RemoteServer">
    <Remote Url="ws://localhost:8080/mcp"/>
</MCP>
```

### Configuration Variables

Use `@{KEY}` syntax to reference external configuration:

```xml
<MCP Name="APIServer">
    <Stdio Executable="/opt/servers/api-mcp">
        <Env Name="API_KEY" Value="@{EXTERNAL_API_KEY}"/>
        <Env Name="DATABASE" Value="@{DB_CONNECTION}"/>
    </Stdio>
</MCP>
```

Store configuration values in globals:

```objectscript
Set ^%AI.Config("EXTERNAL_API_KEY") = "secret-key-123"
Set ^%AI.Config("DB_CONNECTION") = "jdbc:IRIS://localhost:1972/USER"
```

The framework expands these at runtime.

## Building Agentic Applications

An agentic application uses `%AI.Agent` to create autonomous AI assistants that can use tools to accomplish tasks.

### Basic Agentic Application Pattern

```objectscript
Class MyApp.Assistant
{
    /// Run the assistant
    ClassMethod Run(userInput As %String) As %String
    {
        // 1. Create provider
        Set provider = ##class(%AI.Provider).Create("openai", {
            "api_key": apiKey
        })

        // 2. Create agent
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4"
        Set agent.SystemPrompt = "You are a helpful assistant for MyApp."

        // 3. Register tools
        Do agent.UseToolSet("MyApp.Tools")

        // 4. Set policies
        Do agent.ToolManager.SetAuthPolicy(##class(MyApp.ReadOnlyPolicy).%New())
        Do agent.ToolManager.SetAuditPolicy(##class(MyApp.DatabaseAudit).%New())

        // 5. Create session
        Set session = agent.CreateSession()

        // 6. Execute
        Set response = agent.Chat(session, userInput)

        Return response.Content
    }
}
```

### Multi-Turn Conversation Application

```objectscript
Class MyApp.ConversationApp
{
    Property Agent As %AI.Agent;
    Property Session As %AI.Agent.Session;

    Method %OnNew(providerName As %String, apiKey As %String, model As %String) As %Status
    {
        // Initialize provider and agent
        Set provider = ##class(%AI.Provider).Create(providerName, {"api_key": apiKey})
        Set ..Agent = ##class(%AI.Agent).%New(provider)
        Set ..Agent.Model = model
        Set ..Agent.SystemPrompt = "You are a helpful assistant."

        // Register tools
        Do ..Agent.UseToolSet("MyApp.Tools")

        // Create session
        Set ..Session = ..Agent.CreateSession()

        Return $$$OK
    }

    Method Ask(question As %String) As %String
    {
        Set response = ..Agent.Chat(..Session, question)
        Return response.Content
    }

    Method GetStats() As %DynamicObject
    {
        Return ..Session.GetStats()
    }

    Method Reset()
    {
        // Create new session to clear history
        Set ..Session = ..Agent.CreateSession()
    }
}
```

**Usage:**

```objectscript
// Create conversation
Set conv = ##class(MyApp.ConversationApp).%New("openai", apiKey, "gpt-4")

// Multi-turn interaction
Write conv.Ask("What is the capital of France?"), !
// => "The capital of France is Paris."

Write conv.Ask("What is its population?"), !
// => "Paris has a population of approximately 2.2 million people..."

// Check usage
Set stats = conv.GetStats()
Write "Tokens used: ", (stats."total_prompt_tokens" + stats."total_completion_tokens"), !

// Reset conversation
Do conv.Reset()
```

### Streaming Application

```objectscript
Class MyApp.StreamingApp
{
    Property Agent As %AI.Agent;
    Property Session As %AI.Agent.Session;

    Method %OnNew(provider As %AI.Provider, model As %String) As %Status
    {
        Set ..Agent = ##class(%AI.Agent).%New(provider)
        Set ..Agent.Model = model

        Set ..Session = ..Agent.CreateSession()

        Return $$$OK
    }

    Method AskStreaming(question As %String)
    {
        Set callback = ##class(MyApp.StreamCallback).%New()
        Set response = ..Agent.StreamChat(..Session, question, callback, "OnChunk")
        Write !, "Complete.", !
    }
}

Class MyApp.StreamCallback Extends %RegisteredObject
{
    Property Buffer As %String;

    Method OnChunk(delta As %DynamicObject)
    {
        If delta.content '= "" {
            Write delta.content
            Set ..Buffer = ..Buffer _ delta.content
        }

        If delta.%IsDefined("tool_call") && (delta."tool_call" '= "") {
            Set tc = delta."tool_call"
            If tc.%IsDefined("name") && (tc.name '= "") {
                Write !,  "[Calling tool: ", tc.name, "]", !
            }
        }
    }
}
```

### Example: Interactive AI Shell

The `%AI.System::Shell()` method is a complete example of an agentic application. It demonstrates:

- Provider initialization with flexible configuration
- Agent setup with tools and policies
- Session management across multiple turns
- Streaming output with visual feedback
- Command handling (/help, /tools, /stats, etc.)
- Error handling and recovery
- Markdown rendering and syntax highlighting

**Source:** See `cls/AI/System.cls` for the full implementation.

**Running the Shell:**

```objectscript
// Simple
Do ##class(%AI.System).Shell("openai", "sk-...", "gpt-4")

// With tools
Do ##class(%AI.System).Shell("openai", apiKey, "gpt-4", "%AI.Tools.SQL")

// Bedrock — SigV4 (uses AWS credential chain)
Set cfg = {"region": "us-east-1"}
Do ##class(%AI.System).Shell("bedrock", cfg, "anthropic.claude-3-5-sonnet-20241022-v2:0")

// Bedrock — bearer token (note the cross-region inference profile prefix "us.")
Set cfg = {"region": "us-east-1", "bearer_token": "..."}
Do ##class(%AI.System).Shell("bedrock", cfg, "us.anthropic.claude-3-5-sonnet-20241022-v2:0")
// Or rely on the AWS_BEARER_TOKEN_BEDROCK env var instead of putting the token in code:
// Set cfg = {"region": "us-east-1"}
// Do ##class(%AI.System).Shell("bedrock", cfg, "us.anthropic.claude-3-5-sonnet-20241022-v2:0")
```

## Advanced Topics

More advanced, experimental features are covered in the [Advanced Features Guide](ObjectScript_SDK_Advanced.md).

### Multi-Modal Content

Send images with text prompts:

```objectscript
// From base64-encoded image
Method AnalyzeImage(imagePath As %String, question As %String) As %String
{
    // Read and encode image
    Set stream = ##class(%Stream.FileBinary).%New()
    Do stream.LinkToFile(imagePath)
    Set base64 = $SYSTEM.Encryption.Base64Encode(stream)

    // Create content parts
    Set content = [
        {"type": "text", "text": (question)},
        {"type": "image",
         "url": ("data:image/jpeg;base64,"_base64),
         "mime_type": "image/jpeg"}
    ]

    // Send to agent
    Set response = ..Agent.ChatWithContent(..Session, content)
    Return response.Content
}
```

### Logging and Debugging

Enable Rust-side tracing for debugging:

```objectscript
// Enable debug logging
Do ##class(%AI.System).SetLogLevel("debug")
Do ##class(%AI.System).SetLogFile("my-trace.log")

// Run your application
// ...

// Check the log file for detailed traces
Do ##class(%Library.File).TailFile("my-trace.log", 50)

// Disable logging
Do ##class(%AI.System).SetLogLevel("off")
```

**Log Levels:** `trace`, `debug`, `info`, `warn`, `error`, `off`

### Error Handling

```objectscript
Try {
    Set response = agent.Chat(session, input)
    Write response.Content
} Catch ex {
    If ex.Name = "<INTERRUPT>" {
        Write "User interrupted", !
    } ElseIf ex.%IsA("%Exception.StatusException") {
        Write "Error: ", $SYSTEM.Status.GetErrorText(ex.AsStatus()), !
    } Else {
        Write "Unexpected error: ", ex.DisplayString(), !
    }
}
```

### Performance Monitoring

:warning: advanced / experimental feature -- this capability may change significantly before GA release

```objectscript
// Track session performance
Set stats = session.GetStats()

// Calculate tokens per second
Set totalTokens = stats."total_prompt_tokens" + stats."total_completion_tokens"
Set totalSeconds = stats."total_llm_duration_ms" / 1000
Set tokensPerSec = totalTokens / totalSeconds

Write "Throughput: ", $FNUMBER(tokensPerSec, "", 1), " tokens/sec", !

// Context window usage
Set pctUsed = (stats."current_context_tokens" / stats."model_context_size") * 100
Write "Context: ", $FNUMBER(pctUsed, "", 1), "% used", !
```

### Prompt Caching

:warning: advanced / experimental feature -- this capability may change significantly before GA release

Reduce costs by caching portions of input context. Supported by Anthropic, OpenAI (automatic), Gemini (planned).

```objectscript
ClassMethod DemoCaching()
{
    Set provider = ##class(%AI.Provider).Create("anthropic", {"api_key": apiKey})

    // Large system prompt (reused across requests)
    Set systemPrompt = "You are an expert code reviewer... [... 2000+ tokens ...]"

    Set messages = []
    Do messages.%Push({"role": "system", "content": (systemPrompt)})
    Do messages.%Push({"role": "user", "content": "Review: Set x = 1 + 1"})

    // Enable caching
    Set options = ##class(%AI.LLM.CompletionOptions).%New()
    Set options.CacheSystemPrompt = 1
    Set options.CacheTools = 1
    Set options.MinTokensForCache = 1024

    // First request - creates cache
    Set response = provider.ChatComplete("claude-sonnet-4", messages, options)
    Write "Cache creation: ", response.Usage.CacheCreationTokens, " tokens", !
    Write "Cache reads: ", response.Usage.CacheReadTokens, " tokens", !

    // Second request (within TTL) - reads from cache
    Do messages.%Set(1, {"role": "user", "content": "Review: Set y = 2 * 3"})
    Set response2 = provider.ChatComplete("claude-sonnet-4", messages, options)
    Write "Cache creation: ", response2.Usage.CacheCreationTokens, " tokens", !
    Write "Cache reads: ", response2.Usage.CacheReadTokens, " tokens", !
}
```

**Cache TTL:** 5 minutes (Anthropic), 5-10 minutes (OpenAI)

## Best Practices

### 1. System Prompts

Be specific and include formatting guidance:

```objectscript
Set agent.SystemPrompt =
    "You are an expert assistant for InterSystems IRIS." _
    " You have access to database and file system tools." _
    " Always format code in fenced blocks with language tags." _
    " Be concise and accurate." _
    " If you're unsure, say so rather than guessing."
```

### 2. Tool Organization

Group related tools by domain:

```objectscript
// Good - organized
Class MyApp.DatabaseTools Extends %AI.ToolSet { ... }
Class MyApp.ReportingTools Extends %AI.ToolSet { ... }
Class MyApp.AdminTools Extends %AI.ToolSet { ... }

// Avoid - monolithic
Class MyApp.AllTools Extends %AI.ToolSet { ... }
```

### 3. Policy Layering

:warning: advanced / experimental feature - see [Advanced Features Guide](ObjectScript_SDK_Advanced.md)

Use both authorization and audit policies:

```objectscript
// Authorization controls execution
Do agent.ToolManager.SetAuthPolicy(##class(MyApp.ReadOnlyPolicy).%New())

// Audit tracks what happened
Do agent.ToolManager.SetAuditPolicy(##class(MyApp.DatabaseAudit).%New())
```

### 4. Session Management

Create new sessions for new conversations:

```objectscript
// Good - isolated conversations
Method NewConversation()
{
    Set ..Session = ..Agent.CreateSession()
}

// Avoid - reusing sessions across unrelated conversations
// (context pollution)
```

### 5. Resource Cleanup

IRIS automatically cleans up when objects go out of scope, but for long-running processes:

```objectscript
// Explicit cleanup
Do provider.%Close()
```

### 6. Error Recovery

Implement graceful degradation:

```objectscript
Try {
    Set response = agent.Chat(session, input)
} Catch ex {
    // Log error
    Do ##class(MyApp.ErrorLog).LogError(ex)

    // Provide fallback response
    Set response = ##class(%AI.LLM.Response).%New()
    Set response.Content = "I'm having trouble processing that request. Please try again."
}
```

## Troubleshooting

### Provider Creation Fails

```objectscript
Try {
    Set provider = ##class(%AI.Provider).Create("openai", config)
} Catch ex {
    Write "Provider error: ", ex.DisplayString(), !

    // Check configuration
    Do config.%ToJSON()

    // Verify API key is set
    If config."api_key" = "" {
        Write "API key is missing!", !
    }
}
```

### Tools Not Executing

1. Check tool registration:
```objectscript
Set tools = agent.ToolManager.%Discover()
Do tools.%ToJSON()  // Should show your tools
```

2. Enable debug logging:
```objectscript
Do ##class(%AI.System).SetLogLevel("debug")
```

3. Check for authorization denials in audit logs

### Streaming Issues

1. Verify callback method signature:
```objectscript
Method OnChunk(delta As %DynamicObject)
```

2. Check that model supports streaming

3. Ensure callback object is not garbage collected

### High Token Usage

1. Monitor context size:
```objectscript
Set stats = session.GetStats()
If stats."current_context_tokens" > (stats."model_context_size" * 0.8) {
    // Context is getting full - consider resetting
    Write "Warning: Context usage at ", stats."current_context_tokens", " tokens", !
}
```

2. Reset sessions periodically for long conversations