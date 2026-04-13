# InterSystems AI Hub - ObjectScript SDK User Guide

> [!IMPORTANT]
> Please note this is prerelease software, and any APIs and functionality described in this document is subject to change without prior notice before the initial GA release of the AI Hub.

## Overview

InterSystems AI Hub is a comprehensive framework for building AI-powered applications in InterSystems IRIS using ObjectScript. It provides a native, object-oriented API for interacting with Large Language Models (LLMs) and building agentic applications with tool-calling capabilities.

### What is the InterSystems AI Hub?

The InterSystems AI Hub bridges the gap between ObjectScript applications and modern LLM providers. It allows you to:

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

The standard approach is to set environment variables which can then be retrieved by InterSystems IRIS with `$SYSTEM.Util.GetEnviron()`:

1. Set environment variables.
    Linux and macOS:
    ```bash
    export OPENAI_API_KEY="sk-..."
    # OR
    export ANTHROPIC_API_KEY="sk-ant-..."
    ```
    
    In Windows, `$SYSTEM.Util.GetEnviron()` can only retrieve system-level environment variables. To set system-level variables, open an elevated PowerShell session:
    ```powershell
    [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-...', 'Machine')
    # OR
    [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-...', 'Machine')
    ```
    
2. Restart InterSystems IRIS to make your changes visible to the InterSystems IRIS process.
    ```bash
    # Then restart InterSystems IRIS
    iris stop <instance>
    iris start <instance>
    ```

**Important:** IRIS must be restarted after setting environment variables for them to be visible to the IRIS process.

### Verifying API Key Setup

You can verify whether InterSystems IRIS can see your API key using `SYSTEM.Util.GetEnviron()`:

```objectscript
// Check environment variable
USER> Write $System.Util.GetEnviron("OPENAI_API_KEY")
```

Alternatively, you can verify that the API key works by attempting to create an `%AI.Provider`:

```objectscript
// Quick test
USER> Set provider = ##class(%AI.Provider).Create("openai", {"api_key": "sk-..."})
USER> Write provider.Name
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

The `%AI.Agent` class is the core execution engine. It manages the interaction between the LLM, tools, and policies. This is what orchestrates multi-turn conversations with tool-calling. It is responsible for:
- Executing LLM requests with tool schemas
- Handling tool call responses from the LLM
- Invoking tools through the ToolManager
- Applying authorization and audit policies
- Managing streaming and feedback

The `AI.Agent` has the following properties:

```objectscript
Property Provider As %AI.Provider       // LLM provider
Property Model As %String                // Model name override
Property SystemPrompt As %String         // System instructions
Property Temperature As %Float           // Randomness (0.0-2.0)
Property ToolManager As %AI.ToolMgr      // Tool and policy manager
```

#### Creating an Agent

To create an agent, create an instance of `%AI.Provider` and then pass that into the `%AI.Agent` constructor, specifying the `Model`, `SystemPrompt`, and `Temperature`. The following example creates a provider with an OpenAI provider and prompts it to be an assistant:


```objectscript
Set provider = ##class(%AI.Provider).Create("openai", {"api_key": apiKey})
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "gpt-4"
Set agent.SystemPrompt = "You are a helpful assistant."
Set agent.Temperature = 0.7
```

#### Configuring the Model

You can configure LLM parameters by passing in a `JSON` configuration object when you create the session:

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

The following table gives general guidelines for model settings:

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

#### Declarative Agent Configuration

You can simplify agent creation with a declarative configuration. To do this, subclass `%AI.Agent` and then use Parameters and XData blocks to pre-configure the agent. The table below shows the supported provider parameters:

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

You can then create an instance of the agent with `%New()` and configure it with `Init()` (connects to the provider, loads `XData INSTRUCTIONS` and registers `TOOLSETS`):

```objectscript
Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
$$$ThrowOnError(agent.%Init())
// Provider, model, system prompt, and toolsets are all configured
```

**Supported Configuration Parameters**

The following table lists the relevant configuration parameters for `%AI.Agent` subclasses:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `PROVIDER` | Provider name | `"anthropic"`, `"openai"`, `"vertex"` |
| `MODEL` | Model ID | `"claude-sonnet-4-5@20250929"` |
| `APIKEY` | API key (for simple providers) | Read from environment if empty |
| `PROVIDERCONFIG` | JSON config (for complex providers) | `{"region": "us-east-1", ...}` |
| `TOOLSETS` | Comma-separated ToolSet classes | `"%AI.Tools.FileSystem,%AI.Tools.SQL"` |

The following example creates a declarative agent configuration using the `PROVIDER`, `MODEL`, `APIKEY`, and `TOOLSETS` properties. It also contains system `INSTRUCTIONS` with an XData block, which prompts the agent with a description and a list of tools.

1. Subclass `%AI.Agent`, specifying the following parameters and instructions:
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

2. Create a new instance of the agent. Because the class definition of `Sample.AI.Agent.FileSystemAgent` already contains the provider as a parameter, you do not need to specify it on instantiation:

    ```objectscript
    Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
    // Provider, model, system prompt, and toolsets are all configured!
    ```

**Configuration Priority**:

Settings for declarative agents are prioritized as follows:

1. Runtime assignment (highest): `Set agent.Model = "..."`
2. Property `InitialExpression`
3. Parameter value
4. XData block content

##### Using Declarative Agents

The `Sample.AI.Agent.FileSystemAgent` class demonstrates the three main interaction patterns: blocking chat, streaming chat, and multi-modal content:

- **Blocking Chat** - Synchronous request/response:

    ```objectscript
    ClassMethod DemoChat() As %Status
    {
        Write !, "=== Blocking Chat Demo ===", !

        // Create agent - provider created from PROVIDER parameter
        Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
        $$$ThrowOnError(agent.%Init())

        Write "Provider: ", agent.Provider.Name, !
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

- **Streaming Chat** - Real-time response chunks:

    ```objectscript
    ClassMethod DemoStream() As %Status
    {
        Write !, "=== Streaming Chat Demo ===", !

        // Create agent
        Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
        $$$ThrowOnError(agent.%Init())

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

- **Multi-Modal Content** - Text with images or other media:

    ```objectscript
    ClassMethod DemoMultiModal() As %Status
    {
        Write !, "=== Multi-Modal Demo ===", !

        // Create agent
        Set agent = ##class(Sample.AI.Agent.FileSystemAgent).%New()
        $$$ThrowOnError(agent.%Init())

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

The provided `Sample.AI.Agent.FileSystemAgent` class contains demos for each of the main interaction patterns. To run them:

```objectscript
// Run individual demos
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoChat()
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoStream()
Do ##class(Sample.AI.Agent.FileSystemAgent).DemoMultiModal()

// Run all demos
Do ##class(Sample.AI.Agent.FileSystemAgent).Demo()
```

The core methods for these interaction patterns are:

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
    callbackObj As %RegisteredObject = {$$$NULLOREF},
    callbackMethod As %String = ""
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

For advanced use cases, you can also create sessions directly:

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

The `GetStats()` method provides information about the session:

```objectscript
Set stats = session.GetStats()

Write "Interactions: ", stats."total_interactions", !
Write "Prompt tokens: ", stats."total_prompt_tokens", !
Write "Completion tokens: ", stats."total_completion_tokens", !
Write "Tool calls: ", stats."total_tool_calls", !
Write "LLM time: ", stats."total_llm_duration_ms", "ms", !
```

You can use this method to monitor performance:

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


### %AI.ToolMgr - Tool Registry & Policy Manager

The `%AI.ToolMgr` manages tool registration, discovery, and execution. It also enforces authorization and audit policies.

**Tool Discovery:**

```objectscript
// Get all registered tools as STP-format JSON
Set toolsJson = agent.ToolManager.%Discover()

// Returns array in the form:
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

**Built-in Rust Tools:**

The framework ships several high-performance Rust tools ready to use without any extra code.

`rust:filesystem` — file read/list operations (scoped to `base_dir`).

`rust:web_search` — web search via Brave Search (default) or Bing.

| URI | Provider | Required env var |
|-----|----------|-----------------|
| `rust:web_search` | Brave (default) | `BRAVE_SEARCH_API_KEY` |
| `rust:web_search:brave` | Brave | `BRAVE_SEARCH_API_KEY` |
| `rust:web_search:bing` | Bing | `BING_SEARCH_API_KEY` |

Optional config keys (pass as a `%DynamicObject`):
- `api_key` — overrides the environment variable.
- `count` — number of results to return (1–10, default 5).

```objectscript
// Basic web search (reads BRAVE_SEARCH_API_KEY from environment)
Do agent.ToolManager.AddTool("rust:web_search")

// Bing with a result count limit
Do agent.ToolManager.AddTool({"type":"rust:web_search:bing","config":{"count":3}})

// Brave with explicit API key
Do agent.ToolManager.AddTool({"type":"rust:web_search","config":{"api_key":"bsa-...","count":5}})
```

The tool exposes a single `web_search(query, count?)` function. It returns:
```json
{
  "results": [
    {"title": "Example", "url": "https://example.com", "description": "..."}
  ],
  "count": 5
}
```

**Setting Policies:**

:warning: advanced / experimental feature -- this capability may change significantly before GA release

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

A tool is an ObjectScript method or other bit of business logic that an AI can invoke. You can create tools in several ways.

### Method 1: Simple ToolSet with Inline Tools

The simplest way to create a tool is by extending `%AI.ToolSet` and defining tools referencing class methods by name in an `XData` block:

```objectscript
Class MyApp.SimpleTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="SimpleTools">
            <Tool Name="GetTime" Method="GetTime"/>
            <Tool Name="GetUserCount" Method="GetUserCount"/>
        </ToolSet>
    }

    /// Get the current server time in ISO 8601 format.
    ClassMethod GetTime() As %String
    {
        Return $ZDATETIME($HOROLOG, 3)
    }

    /// Get the total number of registered users.
    ClassMethod GetUserCount() As %Integer
    {
        &sql(SELECT COUNT(*) INTO :count FROM Security.Users)
        Return count
    }
}
```

**Using the ToolSet**

You can then provide the tools to an instance of `%AI.Agent`. This example gives the agent `MyApp.SimpleTools`, which the agent can use to respond to the user's query:

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

Tools accept typed parameters directly in the method signature. The framework generates
the JSON Schema for the LLM from the compiled signature automatically.

```objectscript
Class MyApp.Calculator Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="Calculator">
            <Tool Name="Add" Method="Add"/>
        </ToolSet>
    }

    /// Add two numbers (a and b) together and return the sum.
    ClassMethod Add(a As %Float, b As %Float) As %Float
    {
        Return a + b
    }
}
```

Each typed parameter becomes a JSON Schema property. Parameters without a default value are marked required. Supported types: `%String`, `%Integer`, `%Float`, `%Boolean`, `%DynamicObject`, `%DynamicArray`, and any `%JSON.Adaptor` subclass.

### Method 3: Wrapping Existing Classes

You can also give your agent access to existing ObjectScript classes as tools. This includes methods whose documentation is written for developers rather than an LLM; you can use `<Description/>` to replace the description with an LLM-friendly one:

```objectscript
Class MyApp.DataTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="DataTools">
            <Tool Name="SearchPatients" Method="SearchPatients">
                <!-- The method doc is internal; replace it with an LLM-friendly description -->
                <Description>Search for patients by name. Returns a JSON array of matching records, each with id, name, and date of birth.</Description>
            </Tool>
        </ToolSet>
    }

    /// Internal: delegates to Patient.SearchByName, returns JSON for RPC layer.
    ClassMethod SearchPatients(name As %String) As %String
    {
        Set results = ##class(MyApp.Patient).SearchByName(name)

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


### Stateful Tools (Instance Methods)

Tool methods can be either ClassMethods or instance Methods. When they are instance Methods, the ToolSet instance is created once when the session starts and held alive for the entire session. This means instance properties on the ToolSet class — and on any included tool classes — persist across tool calls.

This lets you build tools that accumulate context, cache results, or track state within a conversation without any external storage:

```objectscript
Class MyApp.SessionTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="SessionTools">
            <Tool Name="Remember" Method="Remember"/>
            <Tool Name="Recall"   Method="Recall"/>
            <Tool Name="Forget"   Method="Forget"/>
        </ToolSet>
    }

    Property Notes As %String(MAXLEN = "");

    /// Store a note for later retrieval in this session.
    Method Remember(note As %String(DESCRIPTION = "The note to store")) As %String
    {
        Set ..Notes = ..Notes _ note _ $C(10)
        Return "Noted."
    }

    /// Recall all notes stored in this session.
    Method Recall() As %String
    {
        Return $SELECT(..Notes = "": "No notes stored yet.", 1: ..Notes)
    }

    /// Clear all stored notes.
    Method Forget() As %String
    {
        Set ..Notes = ""
        Return "Notes cleared."
    }
}
```

Instance Methods on **included** tool classes work the same way — a single instance is created per session and reused across all calls to that class's tools:

```objectscript
Class MyApp.MyToolSet Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="MyToolSet">
            <!-- MyApp.CartTools has instance Methods; one instance persists per session -->
            <Include Class="MyApp.CartTools"/>
        </ToolSet>
    }
}
```

> **Note:** State is scoped to the session. Each new session gets a fresh ToolSet instance with zeroed-out properties.

### Filtering Included Tools

When you include a class with `<Include>`, you can narrow which of its tools are exposed to the LLM using the `Tool` attribute (exact match), the `Match` attribute (regex), or child `<Filter>` elements (OR-logic). You can also remove tools from the composed set with `<Exclude>`.

All filtering happens at **compile time** — the ToolSet is compiled once and the resulting tool list is fixed. There is no runtime overhead.

#### Exact match — `Tool=`

Expose only the named tool from the included class:

```objectscript
<ToolSet Name="ReadOnlyOrders">
    <!-- Only expose GetOrder, not CreateOrder, CancelOrder, etc. -->
    <Include Class="MyApp.OrderTools" Tool="GetOrder"/>
</ToolSet>
```

#### Pattern match — `Match=`

`Match` is a POSIX regular expression tested against the tool name. A partial match is sufficient (no need to anchor both ends). Use `^` to anchor to the start:

```objectscript
<ToolSet Name="GettersOnly">
    <!-- Include any tool whose name starts with "Get" -->
    <Include Class="MyApp.CustomerTools" Match="^Get"/>
</ToolSet>
```

```objectscript
<ToolSet Name="SearchAndList">
    <!-- Include tools starting with "Search" OR "List" -->
    <Include Class="MyApp.ProductTools" Match="^(Search|List)"/>
</ToolSet>
```

#### OR-logic — child `<Filter>` elements

When you need to match tools by more than one name pattern, add `<Filter>` children. A tool passes if it matches **any** child filter or the parent `Tool`/`Match` attributes:

```objectscript
<ToolSet Name="SelectedTools">
    <Include Class="MyApp.InventoryTools">
        <Filter Tool="GetStockLevel"/>
        <Filter Tool="GetReorderPoint"/>
        <Filter Match="^List"/>
    </Include>
</ToolSet>
```

This exposes `GetStockLevel`, `GetReorderPoint`, and any tool whose name begins with `List` — all other tools from `MyApp.InventoryTools` are omitted.

#### Excluding tools — `<Exclude>`

`<Exclude>` removes matching tools from the composed set. You can exclude by exact name, regex, or both:

```objectscript
<ToolSet Name="SafeTools">
    <Include Class="MyApp.DatabaseTools"/>
    <!-- Remove destructive operations -->
    <Exclude Match="^(Delete|Drop|Truncate)"/>
</ToolSet>
```

`<Exclude>` also accepts child `<Filter>` elements for OR-logic:

```objectscript
<ToolSet Name="LimitedTools">
    <Include Class="MyApp.AdminTools"/>
    <Exclude>
        <Filter Tool="ResetAllUsers"/>
        <Filter Tool="WipeDatabase"/>
        <Filter Match="^Debug"/>
    </Exclude>
</ToolSet>
```

To exclude tools from a **specific class** only (when you have multiple includes), add the `Class=` attribute to `<Exclude>`:

```objectscript
<ToolSet Name="CompositeTools">
    <Include Class="MyApp.OrderTools"/>
    <Include Class="MyApp.ProductTools"/>
    <!-- Remove Delete only from OrderTools, not from ProductTools -->
    <Exclude Class="MyApp.OrderTools" Tool="DeleteOrder"/>
</ToolSet>
```

#### Combining Include and Exclude

Filters and excludes compose naturally. Include narrows what comes in; Exclude removes from what remains:

```objectscript
<ToolSet Name="CustomerServiceTools">
    <!-- Only Get* and Search* from customer tools -->
    <Include Class="MyApp.CustomerTools" Match="^(Get|Search)"/>
    <!-- All order tools except cancellation -->
    <Include Class="MyApp.OrderTools"/>
    <Exclude Class="MyApp.OrderTools" Match="^Cancel"/>
</ToolSet>
```

#### Summary

| Attribute / Element | Where | Effect |
|---|---|---|
| `Tool="Name"` | `<Include>` or `<Filter>` | Exact tool name match |
| `Match="regex"` | `<Include>`, `<Exclude>`, or `<Filter>` | POSIX regex against tool name |
| `<Filter>` children | Inside `<Include>` or `<Exclude>` | OR-list: tool passes if any child matches |
| `Class="ClassName"` | `<Exclude>` | Scope exclusion to one source class |

> **Processing order:** Within a ToolSet, all `<Include>` elements are processed in declaration order (locally defined `<Tool>` elements win over includes with the same name). All `<Exclude>` elements are applied afterwards, across the full composed set.


### Tool Descriptions

The LLM reads two kinds of description from each tool: the **tool description** (what the tool does and when to call it) and **per-parameter descriptions** (what each argument means). Understanding where each comes from helps you choose the most natural way to document your tools.


#### Tool description

Resolved in priority order:

| Priority | Source | When to use |
|---|---|---|
| 1 | XML `<Description/>` | Wrapping internal methods; any time the method doc is not suitable for an LLM audience |
| 2 | Method doc comment (`///`) | Methods written specifically as tools, where the doc comment is already LLM-friendly |

`<Description/>` completely replaces the description, discarding the method documentation entirely. Without it, the method's `///` comment is used verbatim, so write it with the LLM in mind: what does this tool do, what does it return, and when should the model call it?


#### Parameter descriptions

There are two ways to document parameters, and they can be combined freely:

**1. In the tool description (most natural)**

Document parameters as part of the method doc comment or `<Description/>`. The LLM reads the full tool description and understands parameter meaning from it:

```objectscript
/// Calculate the result of a simple arithmetic expression.
/// a is the left operand, op is the operator (+ - * /), b is the right operand.
ClassMethod Calculate(a As %Numeric, op As %String, b As %Numeric) As %String { ... }
```

**2. Via `DESCRIPTION` type parameters (structured)**

Attach a description directly to each formal argument. This populates the per-parameter `description` field in the JSON Schema, separate from the tool description:

```objectscript
/// Calculate the result of a simple arithmetic expression.
ClassMethod Calculate(
    a As %Numeric(DESCRIPTION = "Left operand"),
    op As %String(DESCRIPTION = "Operator: + - * /"),
    b As %Numeric(DESCRIPTION = "Right operand")
) As %String { ... }
```

Both approaches are effective — the LLM sees the tool description and the parameter schema, and draws on both. Documenting in the method doc is more natural for most developers. `DESCRIPTION` type parameters are more structured and explicitly annotate the schema, but the syntax is verbose. Use whichever fits your style; mixing them is fine.

> **These two sources do not interact.** The method doc comment (or `<Description/>`) drives the tool-level description string. `DESCRIPTION` type parameters populate per-parameter schema fields. Neither affects the other.

### Parameter Types and JSON Schema

The JSON Schema sent to the LLM for each tool parameter is derived automatically from the ObjectScript type declared in the method signature. This applies to both tool parameters and return types.

#### Primitive types

| IRIS type | JSON Schema |
|---|---|
| `%String` | `{"type": "string"}` |
| `%Integer` | `{"type": "integer"}` |
| `%Float`, `%Numeric`, `%Double` | `{"type": "number"}` |
| `%Boolean` | `{"type": "boolean"}` |
| `%Date` | `{"type": "string", "format": "date"}` |
| `%Time` | `{"type": "string", "format": "time"}` |
| `%TimeStamp` | `{"type": "string", "format": "date-time"}` |
| `%DynamicObject` | `{"type": "object"}` |
| `%DynamicArray` | `{"type": "array"}` |
| `%Stream.GlobalCharacter` | `{"type": "string"}` |
| `%Stream.GlobalBinary` | `{"type": "string", "contentEncoding": "base64"}` |

#### Class types

When a parameter is typed to a concrete ObjectScript class (persistent, serial, or registered), the schema is built automatically from its compiled properties:

```objectscript
Class MyApp.Address Extends %RegisteredObject
{
    Property Street As %String;
    Property City As %String;
    Property ZipCode As %String;
}

/// Look up businesses near the given address.
Method FindNearby(address As MyApp.Address, radiusMiles As %Float) As %DynamicArray { ... }
```

The LLM sees `address` as:

```json
{
  "type": "object",
  "properties": {
    "Street": {"type": "string"},
    "City":   {"type": "string"},
    "ZipCode": {"type": "string"}
  }
}
```

Properties are reflected recursively — nested objects work automatically. Circular references are detected and short-circuit to `{"type": "object"}` rather than looping.

#### %JSON.Adaptor classes

If the parameter class extends `%JSON.Adaptor`, the schema respects its JSON configuration:

- **`%JSONFIELDNAME`** — the schema uses the remapped field name, not the property name
- **`%JSONINCLUDE = "none"` or `"outputonly"`** — the property is excluded from the schema

```objectscript
Class MyApp.Product Extends (%RegisteredObject, %JSON.Adaptor)
{
    Property ProductId As %Integer(%JSONFIELDNAME = "id");
    Property Name As %String;
    Property InternalCostCode As %String(%JSONINCLUDE = "none"); // hidden from the LLM
}
```

Schema seen by the LLM:

```json
{"type": "object", "properties": {"id": {"type": "integer"}, "Name": {"type": "string"}}}
```

#### Collections and %DynamicArray

Collection properties on class types map naturally:

- `list of ClassName` → `{"type": "array", "items": { ...schema... }}`
- `array of ClassName` → `{"type": "object", "additionalProperties": { ...schema... }}`

For `%DynamicArray` parameters, add an `ELEMENTTYPE` type parameter to tell the framework what the array contains. Without it the schema is just `{"type": "array"}`; with it the element structure is included:

```objectscript
ClassMethod PlaceOrder(
    customerId As %Integer(DESCRIPTION = "Customer ID"),
    items As %DynamicArray(ELEMENTTYPE = "MyApp.OrderItem", DESCRIPTION = "Items to order")
) As %String { ... }
```

`ELEMENTTYPE` is a schema hint only — it does not affect how the array value is passed to the method at runtime.

> **Note:** Full class-type schema generation applies to plain `%AI.Tool` subclasses (auto-discovered method tools). Tools declared in a ToolSet XML `<Tool/>` element use a simplified schema (string/number/boolean only), since the ToolSet compiler does not have visibility into the class hierarchy at compile time. For tools with complex object parameters, prefer a plain `%AI.Tool` subclass.


### Method 4: Use Built-in Tools

The framework provides built-in tools including a generic `%AI.Tools.SQL`.

The following example specifies `%AI.Tools.SQL` in the class definition:

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

You can also provide `%AI.Tools.SQL` to an agent directly:

```objectscript
Do agent.UseToolSet("%AI.Tools.SQL")
```

## Building ToolSets

ToolSets are collections of tools organized by domain or functionality. They support composition, filtering, and integration with external services.

### ToolSet Structure

Concretely, a ToolSet is an instance of `%AI.Toolset`. Custom ToolSets extend this superclass and have the following structure:
1. Inline tools
2. Included ToolSets
3. Included ToolSets with filtering
4. MCP server (external tools)

All of the above are demonstrated in the following example:


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

    /// Echo back the input.
    ClassMethod Echo(text As %String(DESCRIPTION = "Text to echo")) As %String
    {
        Return "Echo: " _ text
    }
}
```

### Including Other ToolSets

Compose ToolSets by including other ToolSets. When you include a ToolSet, you can specify `Requirement`s, which are metadata passed to the included ToolSet used to customize its behavior.

```xml
<Include Class="%AI.Tools.SQL">
    <Requirement Name="ReadOnly" Value="1"/>
    <Requirement Name="Role" Value="%All"/>
</Include>
```

### Filtering Tools

You can explicitly include or exclude certain tools from your ToolSet with a `Filter`:

#### `<Include>` filtering attributes

Two attributes control which tools are selected from an included class:

| Attribute | Type | Effect |
|---|---|---|
| `Match` | POSIX regex | Include only tools whose names match the pattern |
| `Tool` | Exact string | Include only the named tool (optionally `Class:Method`) |

```xml
<!-- Only Get* and List* tools from OrderManagement -->
<Include Class="Sample.AI.Tools.OrderManagement" Match="^(Get|List)"/>

<!-- Include only the specific GetOrder tool -->
<Include Class="Sample.AI.Tools.OrderManagement" Tool="GetOrder"/>

<!-- Include a specific method by class:method (useful when composing nested ToolSets) -->
<Include Class="Sample.AI.Tools.OrderManagement" Tool="Sample.AI.Tools.OrderManagement:GetOrder"/>
```

**Why `Match` regex?** When your tool class follows a naming convention, a regex selects the
entire category. New methods that fit the convention (e.g. a new `GetCustomer`) are
automatically included without updating the filter. See
[`Sample.AI.ToolSet.ReadOnlyOrders`](cls/Sample/AI/ToolSet/ReadOnlyOrders.cls) and
[`Sample.AI.ToolSet.FullAccessOrders`](cls/Sample/AI/ToolSet/FullAccessOrders.cls) for
a complete example using the same tool class two ways. Both depend on
[`Sample.AI.Tools.OrderManagement`](cls/Sample/AI/Tools/OrderManagement.cls) and the
supporting `Sample.AI.Orders` persistent classes; seed the database before running:

```objectscript
Do ##class(Sample.AI.Orders.Setup).Setup()
```

**Pattern: read-only and full-access views of the same class**

Define all operations in one tool class with a consistent verb-prefix convention, then
create two ToolSets:

```xml
<!-- ReadOnly: Get* and List* only -->
<Include Class="Sample.AI.Tools.OrderManagement" Match="^(Get|List)"/>

<!-- FullAccess: everything (also adds authorization policy) -->
<Include Class="Sample.AI.Tools.OrderManagement"/>
```

#### `<Exclude>` element

`<Exclude>` is a sibling element (not nested inside `<Include>`) that removes
already-collected tools by class and/or name. It is applied after all `<Include>` and
`<Tool>` items have been collected, so it can remove tools regardless of where they came
from.

| Attribute | Type | Matches against |
|---|---|---|
| `Class` | Exact string | Tool's origin class name (fully-qualified) |
| `Tool` | Exact string | Tool name (optionally `Class:Method`) |
| `Match` | POSIX regex | Tool name |

A tool is excluded only when **all** specified attributes match. An `<Exclude/>` with
no attributes is a no-op. `Class` is an exact match — no need to escape dots.

```xml
<ToolSet Name="SafeTools">
  <Include Class="Sample.AI.Tools.Everything"/>

  <!-- Remove specific mutating tools from that class -->
  <Exclude Class="Sample.AI.Tools.Everything" Match="^(Delete|Drop|Reset)"/>

  <!-- Remove a single tool by exact name -->
  <Exclude Tool="DangerousOperation"/>
</ToolSet>
```

#### Child `<Filter>` elements (OR lists)

Both `<Include>` and `<Exclude>` accept one or more child `<Filter>` elements. Multiple filters are OR-ed: a tool passes if it matches **any** one of them. Direct `Tool=` and `Match=` attributes on the parent element participate in the same OR.

This is the concise way to allowlist or denylist several specific tools from one class:

```xml
<ToolSet Name="OrderTools">

  <!-- Include exactly three tools from OrderManagement (OR allowlist) -->
  <Include Class="Sample.AI.Tools.OrderManagement">
    <Filter Tool="GetOrder"/>
    <Filter Tool="ListOrders"/>
    <Filter Tool="UpdateOrderStatus"/>
  </Include>

</ToolSet>
```

Without child filters you would need a separate `<Include>` per tool, which repeats the class name each time. The child filter form is equivalent but more readable when selecting several tools from one class.

`<Exclude>` supports the same syntax for denylisting specific tools:

```xml
<ToolSet Name="SafeTools">
  <Include Class="Sample.AI.Tools.Everything"/>

  <!-- Remove two specific tools from that class (OR denylist) -->
  <Exclude Class="Sample.AI.Tools.Everything">
    <Filter Tool="DeleteAll"/>
    <Filter Tool="ResetDatabase"/>
  </Exclude>

</ToolSet>
```

Each `<Filter>` supports the same `Tool=` (exact name) and `Match=` (POSIX regex, partial/anchored match) attributes as the parent `<Include>`/`<Exclude>`.


### Using External MCP Servers

:warning: In a forthcoming update, this capability will switch to use stored MCP configurations using the IRIS Config Store.

A `<MCP>` element inside a ToolSet definition connects your agent to an external MCP server and makes its tools available alongside your own. The agent treats MCP tools exactly like any other tool; policy enforcement, filtering, and tool composition all apply normally.

This section covers consuming external MCP servers from within a ToolSet.
To expose your own InterSystems IRIS tools as an MCP server (for use by Claude Desktop or other MCP clients), see [Exposing IRIS Tools via iris-mcp-server](MCP_Server_Guide.md).

**Stdio MCP Server:**

```xml
<MCP Name="FileServer">
    <Stdio Executable="/usr/local/bin/mcp-server-filesystem">
        <Env Name="ALLOWED_PATHS" Value="/data,/tmp"/>
        <Env Name="LOG_LEVEL" Value="info"/>
    </Stdio>
</MCP>
```

**Remote MCP Server (HTTP/SSE):**

```xml
<MCP Name="RemoteServer">
    <Remote URL="http://localhost:8080/mcp"/>
</MCP>
```

**Remote MCP Server with authentication:**

```xml
<!-- Bearer token -->
<MCP Name="SecureServer">
    <Remote URL="https://mcp.example.com/mcp"
            AuthType="bearer"
            Token="@{env.MCP_TOKEN}"/>
</MCP>

<!-- HTTP Basic -->
<MCP Name="BasicAuthServer">
    <Remote URL="https://mcp.example.com/mcp"
            AuthType="basic"
            Username="_SYSTEM"
            Password="@{env.MCP_PASSWORD}"/>
</MCP>

<!-- Arbitrary header (API key or custom scheme) -->
<MCP Name="ApiKeyServer">
    <Remote URL="https://mcp.example.com/mcp"
            AuthType="header"
            HeaderName="X-API-Key"
            HeaderValue="@{env.MCP_API_KEY}"/>
</MCP>
```

**Platform-specific Stdio entries:**

When the same toolset is deployed on multiple operating systems, use the `Platform` attribute to select the correct executable per platform. The value is a regex matched against a platform descriptor string built at runtime with the form `"<os> <version> <arch>"`.

Examples:

| Platform | Descriptor string |
|---|---|
| Windows 11 x64 | `windows 10.0 x86_64` |
| Ubuntu 24.04 x64 | `linux ubuntu 24.04 x86_64` |
| macOS Sonoma ARM | `macos 14.5.0 aarch64` |
| macOS Sonoma Intel | `macos 14.5.0 x86_64` |

The first `<Stdio>` element whose `Platform` regex matches wins; an element with no `Platform` attribute is a catch-all fallback.

```xml
<MCP Name="MyServer">
    <!-- Windows only (any version, any architecture) -->
    <Stdio Platform="windows" Executable="my-mcp-server.cmd"/>
    <!-- ARM64 (Apple Silicon or Linux ARM) -->
    <Stdio Platform="aarch64" Executable="/usr/local/bin/my-mcp-server-arm64"/>
    <!-- Everything else (Linux x64, macOS x64, ...) -->
    <Stdio Executable="/usr/local/bin/my-mcp-server"/>
</MCP>
```

More specific matches — pin to an OS version or require both OS and arch:

```xml
<MCP Name="MyServer">
    <!-- Ubuntu 24.x only -->
    <Stdio Platform="ubuntu 24\." Executable="/opt/bin/server-ubuntu24"/>
    <!-- macOS on Apple Silicon -->
    <Stdio Platform="macos.*aarch64" Executable="/opt/homebrew/bin/server"/>
    <!-- Fallback -->
    <Stdio Executable="/usr/local/bin/server"/>
</MCP>
```

The `Platform` attribute works the same way on `<Remote>` elements, allowing different URLs or auth schemes per platform.

### Configuration Variables

:warning: In a forthcoming update, this capability will switch to use stored credentials using the IRIS Config Store.

Use `@{prefix.key}` placeholders to pull values from external sources at runtime. Two prefixes are available by default:

| Prefix | Source | Example |
|---|---|---|
| `env` | OS environment variable | `@{env.HOME}` |
| `config` | `^%AI.Config` global | `@{config.BaseURL}` |
| `wallet` | IRIS Secure Wallet | `@{wallet.AISecrets.OpenAIKey}` |

```xml
<MCP Name="APIServer">
    <Stdio Executable="/opt/servers/api-mcp">
        <Env Name="API_KEY" Value="@{wallet.AISecrets.ExternalAPIKey}"/>
        <Env Name="DATABASE" Value="@{config.DB_CONNECTION}"/>
    </Stdio>
</MCP>
```

Register values at startup:

```objectscript
// ^%AI.Config global (plain config values)
Set ^%AI.Config("DB_CONNECTION") = "jdbc:IRIS://localhost:1972/USER"

// IRIS Secure Wallet (secrets — requires %Admin_Wallet:USE or CUSTOM usage)
Do ##class(%Wallet.KeyValue).Create("AISecrets.ExternalAPIKey", {
    "Secret": "sk-proj-...",
    "Usage": ["CUSTOM"]})

// Register the wallet and config stores (call once at startup)
Do ##class(%AI.Utils.SettingStore).RegisterDefaults()
```

Expansion is performed by the Rust SettingExpander, so the same `@{...}` syntax works everywhere in the framework: ToolSet config, provider settings, and agent system prompts.

### Exposing IRIS Tools via `iris-mcp-server`

`iris-mcp-server` is a standalone Rust process that bridges LLM clients (Claude Desktop, Python MCP clients, etc.) to IRIS tools over the wgproto protocol. It uses two independent authentication layers: one for the `wgproto` transport connection and one for per-request CSP application identity.

See [`MCP_Server_Guide.md`](MCP_Server_Guide.md) for full configuration and authentication details.

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

    Method OnChunk(chunk As %String)
    {
        Write chunk
        Set ..Buffer = ..Buffer _ chunk
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

    // Create content parts — use the internal format with "data" for base64 images
    Set content = [
        {"type": "text", "text": (question)},
        {"type": "image",
         "data": (base64),
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

### Prompt Caching

:warning: advanced / experimental feature -- this capability may change significantly before GA release

You can reduce costs by caching portions of input context. This is supported by various providers, including Anthropic, OpenAI (automatic), and Gemini (automatic):

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

InterSystems IRIS automatically cleans up when objects go out of scope, but for long-running processes, you should call `%Close()`:

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

1. Verify that the tools are registered:
    ```objectscript
    Set tools = agent.ToolManager.%Discover()
    Do tools.%ToJSON()  // Should show your tools
    ```

2. Enable debug logging:
    ```objectscript
    Do ##class(%AI.System).SetLogLevel("debug")
    ```

3. Check for authorization denials in audit logs.

### Streaming Issues

1. Verify callback method signature:
    ```objectscript
    Method OnChunk(chunk As %String)
    ```

2. Verify that model supports streaming

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

2. Reset sessions periodically for long conversations.