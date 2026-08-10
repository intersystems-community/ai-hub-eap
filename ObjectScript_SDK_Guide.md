# InterSystems AI Hub - ObjectScript SDK User Guide

> [!IMPORTANT]
> Please note this is prerelease software, and any APIs and functionality described in this document is subject to change without prior notice before the initial GA release of the AI Hub.

**Version:** 1.2.0

## What's New in This Guide

This section summarises the user-facing changes in this cycle that affect how you write code. Internal improvements (performance, security hardening, bug fixes) are covered in the separate release notes.

### Progressive-disclosure skills

The Skills API now uses progressive disclosure: a skill's instructions and tools stay hidden from the model until it activates the skill on demand via a builtin `load_skill` tool. Skills are an experimental feature — see the [Advanced Features Guide](ObjectScript_SDK_Advanced.md#skills-aiagentskill) for the full model and migration notes.

### New provider: Kimi (Moonshot AI)

Kimi (Moonshot AI), including the newly released `kimi-k3`, is now a supported provider: `##class(%AI.Provider).Create("kimi", {"api_key": "..."})` (alias: `"moonshot"`). Kimi's models are open-weight, so `base_url` can point at a self-hosted server or another OpenAI-compatible endpoint instead of Moonshot's own hosted API. See the provider table in [Core Components](#aiprovider---llm-provider-interface) for details.

### `SKILLS` parameter on declarative agents

Declarative `%AI.Agent` subclasses now support a `SKILLS` parameter alongside `TOOLSETS`. This is part of the experimental Skills feature — see the [Advanced Features Guide](ObjectScript_SDK_Advanced.md#skills-aiagentskill).

### Agent instruction templating

The `XData INSTRUCTIONS` block now supports `{{name}}` variable substitution and `{{= expr }}` ObjectScript expression blocks. Class properties are automatically available as template variables. Pass additional values in the optional context argument to `%Init()`:

```objectscript
$$$ThrowOnError(agent.%Init({"customerName": "Alice", "tier": "Gold"}))
```

### Session persistence and restore

Saved sessions restore automatically. For declarative `%AI.Agent` subclasses the recommended path is `%InitWithSession`, which configures the agent from its class parameters and replays the saved conversation in one call:

```objectscript
Set agent = ##class(MyApp.MyAgent).%New()
Set session = ##class(%AI.Agent.Session).%OpenId(id, , .sc)
$$$ThrowOnError(sc)
$$$ThrowOnError(agent.%InitWithSession(session))
// Ready to continue
Set response = agent.Chat(session, "Continue where we left off")
$$$ThrowOnError(session.%Save())
```
For programmatic agents, call `%Init()` first then assign the loaded session to `agent.Session` — the assignment automatically reconnects the session to the live agent context.

### Provider naming: xAI

The xAI (Grok) provider is now identified as `"xai"`. The alias `"grok"` still works for backwards compatibility, but `"xai"` is the canonical name.

### Planning Skill (%AI.Skills.Planning)

A new built-in experimental skill giving any agent structured long-task planning (scratchpad + hierarchical task list). See the [Advanced Features Guide](ObjectScript_SDK_Advanced.md#planning-skill-aiskillsplanning).

### Custom authentication for MCP services (`OnAuthenticate`)

`%AI.MCP.Service` subclasses can now override `OnAuthenticate()` to validate a custom credential -- an API key from your own key-management UI, Basic auth, or any other scheme carried in the `Authorization` header -- without needing to know whether a given tool call arrives over REST or WebSocket; the base class calls it from both. See [Custom Authentication (OnAuthenticate)](#custom-authentication-onauthenticate) for details.

---


## Table of Contents

- [InterSystems AI Hub - ObjectScript SDK User Guide](#intersystems-ai-hub---objectscript-sdk-user-guide)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [What is the InterSystems AI Hub?](#what-is-the-intersystems-ai-hub)
    - [Architecture](#architecture)
  - [Getting Started: API Key Setup](#getting-started-api-key-setup)
    - [Current method: Environment Variables (Requires IRIS Restart)](#current-method-environment-variables-requires-iris-restart)
    - [Config Store Support](#config-store-support)
  - [Core Components](#core-components)
    - [`%AI.Provider` - LLM Provider Interface](#aiprovider---llm-provider-interface)
    - [`%AI.Agent` - Execution Engine](#aiagent---execution-engine)
      - [Creating an Agent](#creating-an-agent)
      - [Configuring the Model](#configuring-the-model)
      - [Controlling the Agentic Loop](#controlling-the-agentic-loop)
      - [Declarative Agent Configuration](#declarative-agent-configuration)
        - [Using Declarative Agents](#using-declarative-agents)
    - [%AI.Agent.Session - Session Management](#aiagentsession---session-management)
    - [Advanced Session Management](#advanced-session-management)
    - [%AI.ToolMgr - Tool Registry \& Policy Manager](#aitoolmgr---tool-registry--policy-manager)
      - [Tool Policies](#tool-policies)
    - [%AI.LLM.Response - Response Object](#aillmresponse---response-object)
  - [Building Tools](#building-tools)
    - [Method 1: Simple ToolSet with Inline Tools](#method-1-simple-toolset-with-inline-tools)
    - [Method 2: Tools with Parameters](#method-2-tools-with-parameters)
    - [Method 3: Wrapping Existing Classes](#method-3-wrapping-existing-classes)
    - [Stateful Tools (Instance Methods)](#stateful-tools-instance-methods)
    - [Filtering Included Tools](#filtering-included-tools)
      - [Exact match — `Tool=`](#exact-match--tool)
      - [Pattern match — `Match=`](#pattern-match--match)
      - [OR-logic — child `<Filter>` elements](#or-logic--child-filter-elements)
      - [Excluding tools — `<Exclude>`](#excluding-tools--exclude)
      - [Combining Include and Exclude](#combining-include-and-exclude)
      - [Summary](#summary)
    - [Tool Descriptions](#tool-descriptions)
      - [Tool description](#tool-description)
      - [Parameter descriptions](#parameter-descriptions)
    - [Parameter Types and JSON Schema](#parameter-types-and-json-schema)
      - [Primitive types](#primitive-types)
      - [Class types](#class-types)
      - [%JSON.Adaptor classes](#jsonadaptor-classes)
      - [Collections and %DynamicArray](#collections-and-dynamicarray)
    - [Method 4: Use Built-in Tools](#method-4-use-built-in-tools)
    - [Method 5: Query-as-Tool](#method-5-query-as-tool)
    - [Tool Class Parameters](#tool-class-parameters)
      - [`REQUIRESAUTH` — mark a class as requiring authorization](#requiresauth--mark-a-class-as-requiring-authorization)
      - [`DISCOVERYLIMIT` — prevent inherited methods from leaking](#discoverylimit--prevent-inherited-methods-from-leaking)
      - [`STATEFUL` — override automatic statefulness detection](#stateful--override-automatic-statefulness-detection)
    - [Advanced: Custom Codec Hooks](#advanced-custom-codec-hooks)
      - [`%Decode` — inbound argument decoding](#decode--inbound-argument-decoding)
      - [`%Encode` — outbound return value encoding](#encode--outbound-return-value-encoding)
      - [Scope](#scope)
  - [Building Agent Skills](#building-agent-skills) 
  - [Building ToolSets](#building-toolsets)
    - [ToolSet Structure](#toolset-structure)
    - [Including Other ToolSets](#including-other-toolsets)
    - [Filtering Tools](#filtering-tools)
      - [`<Include>` filtering attributes](#include-filtering-attributes)
      - [`<Exclude>` element](#exclude-element)
      - [Child `<Filter>` elements (OR lists)](#child-filter-elements-or-lists)
    - [Inline SQL Queries](#inline-sql-queries)
      - [`<Query>` attributes](#query-attributes)
      - [Writing the SQL](#writing-the-sql)
      - [Parameter type mapping](#parameter-type-mapping)
      - [Handling optional parameters](#handling-optional-parameters)
      - [Result envelope](#result-envelope)
      - [Row limits](#row-limits)
      - [Filtering `<Query>` tools](#filtering-query-tools)
    - [Using External MCP Servers](#using-external-mcp-servers)
    - [Configuration Variables](#configuration-variables)
      - [`env` and `wallet`](#env-and-wallet)
      - [`config` — InterSystems IRIS ConfigStore](#config--intersystems-iris-configstore)
    - [Exposing IRIS Tools via `iris-mcp-server`](#exposing-iris-tools-via-iris-mcp-server)
  - [Building Agentic Applications](#building-agentic-applications)
    - [Basic Agentic Application Pattern](#basic-agentic-application-pattern)
    - [Multi-Turn Conversation Application](#multi-turn-conversation-application)
    - [Streaming Application](#streaming-application)
    - [Example: Interactive AI Shell](#example-interactive-ai-shell)
  - [Advanced Topics](#advanced-topics)
    - [Multi-Modal Content](#multi-modal-content)
    - [Logging and Debugging](#logging-and-debugging)
    - [Error Handling](#error-handling)
    - [Prompt Caching](#prompt-caching)
  - [Best Practices](#best-practices)
    - [1. System Prompts](#1-system-prompts)
    - [2. Tool Organization](#2-tool-organization)
    - [3. Policy Layering](#3-policy-layering)
    - [4. Session Management](#4-session-management)
    - [5. Resource Cleanup](#5-resource-cleanup)
    - [6. Error Recovery](#6-error-recovery)
  - [Troubleshooting](#troubleshooting)
    - [Provider Creation Fails](#provider-creation-fails)
    - [Tools Not Executing](#tools-not-executing)
    - [Streaming Issues](#streaming-issues)
    - [High Token Usage](#high-token-usage)


## Overview

InterSystems AI Hub is a comprehensive framework for building AI-powered applications in InterSystems IRIS using ObjectScript. It provides a native, object-oriented API for interacting with Large Language Models (LLMs) and building agentic applications with tool-calling capabilities.

### What is the InterSystems AI Hub?

The InterSystems AI Hub bridges the gap between ObjectScript applications and modern LLM providers. It allows you to:

- **Integrate multiple LLM providers** - OpenAI, Anthropic, Google (Gemini/Vertex), AWS Bedrock, Meta, xAI, NVIDIA NIM, Kimi/Moonshot AI, DeepSeek, OpenRouter, GLM/Z.ai, Zhipu/BigModel
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

:warning: Full support for the [IRIS Config Store](Config_Store_Guide.md) is still a work in progress. In the current version of the AI Hub, you can still use simple environment variables to pass API keys.

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

### Config Store Support

Support for the IRIS Config Store is still a WIP, but the following trick with the `OnInit()` callback can get you going for Agents and Providers:

```objectscript
Class Demo.MyAgent Extends %AI.Agent
{

/* ... */

Parameter MODELCONFIGNAME = "MyConfigName";

Method %OnInit() As %Status
{
    set sc = $$$OK
    try {

        if ..Provider="" && ..#MODELCONFIGNAME'="" {
            set sc = ..GetProviderForConfig(..#MODELCONFIGNAME, .provider, .model)
            quit:$$$ISERR(sc)
            set ..Provider = provider
            set ..Model = model
        }

    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

/// This method will be subsumed by %AI.Provider updates
ClassMethod GetProviderForConfig(configName as %String, Output provider As %AI.Provider, Output model as %String) as %Status [ Internal]
{
    set sc = $$$OK
    try {
        set sc = ##class(%ConfigStore.Configuration).GetDetails("AI.LLM."_configName, .details, 0, 1)
        quit:$$$ISERR(sc)

        set provider = ##class(%AI.Provider).Create(details."model_provider", details)

        set model = details."model"

    } catch (ex) {
        set sc = ex.AsStatus()
    }
    quit sc
}

}
```

Check out the [Config Store guide](Config_Store_Guide.md) for more details and examples on how to store configuration data securely.

## Core Components

### `%AI.Provider` - LLM Provider Interface

The `%AI.Provider` class represents a connection to an LLM provider. It handles API communication, model selection, and response parsing.

**Creating a Provider:**

```objectscript
ClassMethod Create(name As %String, settings As %DynamicObject) As %AI.Provider
```

**Supported Providers:**

| Provider | Name | Key Settings |
|----------|------|--------------|
| OpenAI | `"openai"` | `api_key`, `org_id`, `base_url` (regional keys — e.g. `https://us.api.openai.com/v1`) |
| Anthropic | `"anthropic"` | `api_key` |
| Google Gemini | `"gemini"` | `api_key` |
| Google Vertex AI | `"vertex"` | `project_id`, `region`, `service_account_path`, `service_account_json` |
| AWS Bedrock | `"bedrock"` | `region` (SigV4) or `bearer_token` + `region` |
| Meta Llama | `"meta"` | `api_key` |
| xAI | `"xai"` (alias: `"grok"`) | `api_key` |
| NVIDIA NIM | `"nim"` | `base_url`, `api_key` (optional) |
| DeepSeek | `"deepseek"` | `api_key` |
| Kimi (Moonshot AI) | `"kimi"` (alias: `"moonshot"`) | `api_key`, `base_url` (open-weight -- points at Moonshot's hosted API by default, or a self-hosted/alternate OpenAI-compatible endpoint) |
| OpenRouter | `"openrouter"` | `api_key`, `site_url`, `site_name` |
| ollama | `"openai"` | `base_url`, `api_key` - see example below using their [openai compatibility](https://docs.ollama.com/api/openai-compatibility)  |
| GLM / Z.ai | `"zai"` (alias: `"glm"`) | `api_key` |
| Zhipu / BigModel | `"zhipu"` (alias: `"bigmodel"`) | `api_key` |

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
// Note: Bedrock API keys are region-specific.  The "region" value must
// match the region where the key was generated in the Bedrock console.

// DeepSeek
Set provider = ##class(%AI.Provider).Create("deepseek", {
    "api_key": "sk-..."
})

// Kimi (Moonshot AI) -- hosted API by default
Set provider = ##class(%AI.Provider).Create("kimi", {
    "api_key": "sk-..."
})

// Kimi -- self-hosted / alternate OpenAI-compatible endpoint (open-weight model)
Set provider = ##class(%AI.Provider).Create("kimi", {
    "api_key": "not-needed-for-local-servers",
    "base_url": "http://localhost:8000/v1/"
})

// OpenRouter — api_key is required; site_url and site_name are optional identity
// headers shown in the OpenRouter dashboard
Set provider = ##class(%AI.Provider).Create("openrouter", {
    "api_key": "sk-or-...",
    "site_url": "https://myapp.example.com",
    "site_name": "My App"
})

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

**HTTP and TLS configuration:**

All providers use an underlying HTTP client that can be configured for enterprise network requirements. Pass an `http_config` object alongside the provider settings:

```objectscript
// Private or internal CA certificate (recommended for internal PKI)
Set provider = ##class(%AI.Provider).Create("openai", {
    "api_key": "sk-...",
    "http_config": {
        "tls": {
            "ca_certificates": ["/etc/ssl/certs/my-internal-ca.pem"]
        },
        "connect_timeout_secs": 10,
        "request_timeout_secs": 120
    }
})

// Mutual TLS (client certificate)
Set provider = ##class(%AI.Provider).Create("openai", {
    "api_key": "sk-...",
    "http_config": {
        "tls": {
            "client_certificate": {
                "cert_path": "/etc/ssl/client.pem",
                "key_path":  "/etc/ssl/client.key"
            }
        }
    }
})

// Proxy
Set provider = ##class(%AI.Provider).Create("openai", {
    "api_key": "sk-...",
    "http_config": {
        "proxy_url": "http://proxy.corp.example.com:8080"
    }
})
```

The `tls` block also accepts `accept_invalid_certs` and `accept_invalid_hostnames` flags to disable certificate validation entirely. These exist only as a break-glass option (for example, while an expired certificate is being replaced). Because disabling TLS validation in production is dangerous, both flags require the environment variable `ALLOW_DANGEROUS_TLS=1` to be set in the IRIS process; provider creation fails with a configuration error if the variable is absent. Use a private CA bundle instead whenever possible.


### `%AI.Agent` - Execution Engine

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
    "max_iterations": 10,        // Tool-call rounds per Chat() turn (0 = no hard cap)
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
| **temperature: 0.4-0.7** | Medium | General purpose |
| **temperature: 0.8-1.2** | High | Creative writing, brainstorming |
| **temperature: 1.3-2.0** | Very High | Experimental, may be incoherent |

Temperature` has no default -- if you don't set it, no `temperature` field is sent at all and the provider applies its own default. Leave it unset unless you have a specific reason to override it: some models (reasoning models on several providers, and Kimi's `kimi-k3`/`kimi-k2.x`) reject any explicit value other than their fixed default and return an API error.
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
#### Controlling the Agentic Loop

`Run()` and the inner tool-call loop have independent iteration controls. Understanding both lets you tune an agent for simple conversational use or deep multi-step work.

**`%AI.Agent.MaxIterations`** — the outer loop in `Run()`. Each iteration is one full turn: a prompt sent to the LLM and a response received. `Run()` keeps looping until the model produces a response with no tool calls (done) or `MaxIterations` is reached. Defaults to `10`. Set it to a value that covers the number of turns you expect:

```objectscript
Set agent.MaxIterations = 20   // allow up to 20 turns in Run()
```

**`max_iterations` in `CreateSession`** — the inner tool-call limit per `Chat()` call. Within a single turn, the model may call multiple tools before producing a final response. This cap limits how many back-and-forth tool rounds happen inside one turn. Pass `0` or omit it entirely to remove the hard cap:

```objectscript
Set session = agent.CreateSession({"max_iterations": 0})   // no inner cap
```

**Loop detection** — a safety mechanism that runs regardless of iteration limits. After each round of tool calls, the agent checks whether the tool calls and their results are producing new information. If the same pattern repeats without progress, it first injects a strategy nudge into the context to prompt the model to try a different approach. If repetition continues, it returns a `LoopDetected` error. This catches infinite loops that a hard iteration count would not catch (e.g. the model repeatedly calling a tool that returns the same error). Setting `max_iterations = 0` is safe precisely because loop detection is always active.

**Choosing values:**

| Use case | `MaxIterations` | `max_iterations` |
|---|---|---|
| Simple Q&A, no tools | 1 | 5 |
| Agent with a few tools | 10 (default) | 10 (default) |
| Planning skill, multi-step | 30–50 | 0 (no cap) |
| Unknown complexity | 20–30 | 0 (no cap) |

#### Declarative Agent Configuration

You can simplify agent creation with a declarative configuration. To do this, subclass `%AI.Agent` and then use Parameters and XData blocks to pre-configure the agent. The table below shows the supported provider parameters:

```objectscript
Class Sample.AI.Agent.FileSystemAgent Extends %AI.Agent
{
  /// Provider to use
  Parameter PROVIDER = "anthropic";

  /// Model to use
  Parameter MODEL = "claude-sonnet-4-5@20250929";

  /// API key -- expand from environment variable at runtime
  Parameter APIKEY = "@{env.ANTHROPIC_API_KEY}";

  /// Comma-separated list of ToolSets
  Parameter TOOLSETS = "%AI.Tools.FileSystem";

  /// System Instructions in Markdown
  XData INSTRUCTIONS [ MimeType = text/markdown ]
  {
# File System Assistant

You are a helpful AI assistant specialized in file system operations.

## Available Tools
- File System Operations
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
| `PROVIDER` | Provider name — optional if `PROVIDERCONFIG` includes `model_provider` | `"anthropic"`, `"openai"`, `"vertex"` |
| `MODEL` | Model ID | `"claude-sonnet-4-5@20250929"` |
| `APIKEY` | API key — supports `@{prefix.key}` placeholders | `"@{env.OPENAI_API_KEY}"`, `"@{wallet.MySecrets.Key}"` |
| `PROVIDERCONFIG` | Full provider config as JSON — supports `@{prefix.key}` placeholders and may include `model_provider` to replace `PROVIDER` | `"@{config.MyLLM}"`, `"{""project_id"":""my-proj"",""region"":""@{env.REGION}""}"` |
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

    /// API key — expand from environment variable at runtime
    Parameter APIKEY = "@{env.ANTHROPIC_API_KEY}";

    /// Comma-separated list of ToolSets
    Parameter TOOLSETS = "%AI.Tools.FileSystem";

    /// System Instructions in Markdown
    XData INSTRUCTIONS [ MimeType = text/markdown ]
    {
    # File System Assistant

    You are a helpful AI assistant specialized in file system operations.

    ## Available Tools
    - File System Operations
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

// Optional: Pass configuration for caching, iteration limits, model settings, etc.
Set config = {
    "max_iterations": 10,     // tool-call rounds per Chat() turn; 0 = no hard cap
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

**Inspecting context:**

```objectscript
// Get the raw message array (role/content pairs)
Set messages = session.GetContext()
Set iter = messages.%GetIterator()
While iter.%GetNext(.i, .msg) {
    Write msg.role, ": ", $EXTRACT(msg.content, 1, 80), "...", !
}
```

### Advanced Session Management

:warning: The following features are experimental and for advanced use only. Signatures and persistence may change in a future version.

**Resetting sessions:**

Three granular reset methods let you clear different parts of session state:

```objectscript
session.Reset()          // Clear everything: context, stats, checkpoints, summary
session.ResetContext()   // Clear context and checkpoints; preserve stats
session.ResetStats()     // Reset stats only; context and checkpoints are preserved
```

**Checkpoints — save and restore conversation state:**

Name a point in the conversation and rewind to it later. Useful for branching conversations or recovering from a bad tool result:

```objectscript
// Save a checkpoint after the user confirms their request
$$$ThrowOnError(session.AddCheckpoint("confirmed", "User confirmed order intent"))

// ... more turns ...

// Something went wrong — rewind to the checkpoint
$$$ThrowOnError(session.RewindTo("confirmed"))

// List all checkpoints
Set cps = session.ListCheckpoints()
Set iter = cps.%GetIterator()
While iter.%GetNext(.i, .cp) {
    Write cp.name, " @ msg ", cp.message_index, " — ", cp.note, !
}

// Remove a checkpoint when no longer needed
Do session.RemoveCheckpoint("confirmed")
```

**Forking — branch a conversation:**

`Fork()` creates a deep copy of the session. The original is unchanged. Forked sessions are independent — changes to one don't affect the other:

```objectscript
// Branch the conversation to explore two different approaches
Set main    = session
Set branch  = session.Fork()

// Run different paths
Set r1 = agent.Chat(main,   "Try approach A")
Set r2 = agent.Chat(branch, "Try approach B")

// keepStats:1 copies current stats into the fork (default is fresh stats)
Set fork2 = session.Fork(1)
```

**Summarizing long conversations:**

When context grows too long, summarize the oldest messages in-place, preserving the most recent turns for continuity. The summary is stored alongside the context and referenced in future turns:

```objectscript
// Compact the session: summarize all but the 10 most recent messages
$$$ThrowOnError(session.Summarize(provider))

// Control how many recent messages to keep intact
$$$ThrowOnError(session.Summarize(provider, "", 15))

// Use a specific model for summarization (leave "" to use the session's model)
$$$ThrowOnError(session.Summarize(provider, "gpt-4o-mini", 10))

// Supply a custom summarization prompt
$$$ThrowOnError(session.Summarize(provider, "", 10, "Summarise as bullet points."))
```

`ForkAndSummarize()` is the non-destructive version — it creates a fork and summarizes the copy, leaving the original intact:

```objectscript
// Create a compacted copy without touching the live session
Set compact = session.ForkAndSummarize(provider)
```

**Automatic compaction:**

Set `AutoCompactOnTokenLimit = 1` on the agent to trigger compaction automatically when the context window fills. Without this, hitting the token limit raises an error:

```objectscript
Set agent.AutoCompactOnTokenLimit = 1  // compact automatically instead of erroring
```

**Saving and restoring sessions:**

`%AI.Agent.Session` is a `%Persistent` class. Call `%Save()` at any point during a conversation and the session state is written to the IRIS database. Subsequent saves are incremental — only new messages are appended.

```objectscript
// Save after each turn in a stateless REST handler
Set response = agent.Chat(session, userMessage)
$$$ThrowOnError(session.%Save())
Set sessionId = session.%Id()   // store this for the next request
```

To restore a saved session, load it from the database and reconnect it to an agent. Choose the pattern that matches how you created the agent:

**Pattern 1 — declarative `%AI.Agent` subclasses** (recommended for REST handlers):

```objectscript
// Restore using %InitWithSession: configures the agent from its class parameters
// and replays the saved conversation in one call.
Set agent = ##class(MyApp.MyAgent).%New()
Set session = ##class(%AI.Agent.Session).%OpenId(sessionId, , .sc)
$$$ThrowOnError(sc)
$$$ThrowOnError(agent.%InitWithSession(session))
Set response = agent.Chat(session, "Continue where we left off")
$$$ThrowOnError(session.%Save())
```

**Pattern 2 — programmatic agents** (when you build the agent imperatively):

```objectscript
// After %Init() is called, assigning a loaded session reconnects it automatically.
Set agent = ##class(%AI.Agent).%New(provider)
$$$ThrowOnError(agent.%Init())
Set session = ##class(%AI.Agent.Session).%OpenId(sessionId, , .sc)
$$$ThrowOnError(sc)
Set agent.Session = session   // reconnects the session to the live agent
Set response = agent.Chat(session, "Continue where we left off")
$$$ThrowOnError(session.%Save())
```

**Exporting and importing session state as JSON:**

`Export()` and `Import()` are for cross-instance transfer or storing sessions in an external system — they are not needed for normal within-IRIS persistence (use `%Save`/`%OpenId` for that).

```objectscript
// Export the full session as a JSON string
Set json = session.Export()
// -- transfer json across processes, store externally, etc. --

// Import into a new live session (the session must already be active)
Set newSession = agent.CreateSession()
$$$ThrowOnError(newSession.Import(json))
**Direct message editing:**

For advanced use cases — injecting tool results, correcting facts, building training data — you can read and modify individual messages:

```objectscript
// Get a message by 0-based index
Set msg = session.GetMessage(0)
Write msg.role, ": ", msg.content, !

// Replace a message
Set msg.content = "Updated content"
$$$ThrowOnError(session.SetMessage(0, msg))

// Insert a synthetic message before index 2
$$$ThrowOnError(session.InsertMessage(2, {
    "role": "user",
    "content": "Actually, disregard that last request."
}))

// Remove a message (checkpoint indices update automatically)
Set removed = session.RemoveMessage(3)
```

**Tagging messages:**

Tags let you label individual messages with arbitrary keywords and then find or remove them by tag. Useful for marking grounding context, flagging tool results for review, or pruning specific message categories without touching the rest of the conversation.

Tags are normalized before storage: lowercased and stripped of all non-alphanumeric characters. `"Hello World!"` and `"helloworld"` refer to the same tag. Duplicate normalized tags on a message are silently ignored.

```objectscript
// Tag a message (0-based index). Comma-separated; all tags normalized.
$$$ThrowOnError(session.TagMessage(0, "grounding,userProvided"))
$$$ThrowOnError(session.TagMessage(2, "toolResult"))

// Get the normalized tags on a message as a %DynamicArray (sorted)
Set tags = session.GetTags(0)
// -> ["grounding", "userprovided"]

// Remove specific tags from a message
$$$ThrowOnError(session.UntagMessage(0, "grounding"))

// Remove all tags from a message
$$$ThrowOnError(session.ClearTags(2))

// Find all messages (by 0-based index) that carry a tag
Set indices = session.FindByTag("toolResult")
// -> [2, 5, 7]

// Delete all messages that carry a tag (back-to-front; checkpoint indices stay valid)
Set deleted = session.DeleteByTag("toolResult")
Write "Removed ", deleted, " messages", !
```

Tags are fully persistent: they survive `Export()`/`Import()`, `Fork()`, and `%Save()`/`Load()`. When a message is inserted or removed, tag sets shift in lockstep with checkpoints so indices remain consistent.


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

`rust:shell` — shell command execution with background task support.

**Authorization required.** The shell tool sets `requires_auth: true` — agents cannot call it unless an authorization policy is configured. Without a policy the tool is unavailable to the LLM. Use `%AI.Policy.ConsoleAuth` for interactive sessions or write a custom `%AI.Policy.Authorization` subclass for programmatic approval rules.

**Stateful tool.** The shell tool maintains working-directory state and background-task state in the process instance that handled the `AddTool` call. Subsequent calls to `task_io`, `terminate_task`, and `list_tasks` must reach the same process instance. When deploying behind a CSP job pool or REST gateway, the session must use a dedicated (non-shared) connection — i.e. the MCP WebSocket endpoint rather than the stateless REST endpoint.

```objectscript
// Add shell tools (bash, terminate_task, task_io, list_tasks, change_directory, ...)
// Authorization policy required — the LLM cannot call the shell without one.
Do agent.ToolManager.AddTool("rust:shell")
Do agent.ToolManager.SetAuthPolicy(##class(%AI.Policy.ConsoleAuth).%New())
```

The shell tool exposes:

| Tool | Description | Auth required |
|---|---|---|
| `bash` | Execute a shell command (synchronous or background) | Yes |
| `terminate_task` | Terminate a running background task | Yes |
| `task_io` | Send stdin / read stdout of a background task | No |
| `list_tasks` | List all background tasks for this session | No |
| `change_directory` | Change the working directory (persists across commands) | No |
| `get_working_directory` | Get the current working directory | No |

When `bash` is called with `run_in_background: true`, the command runs asynchronously and returns a `task_id`. Use `task_io` to stream output and `terminate_task` to stop it. Task IDs are random (UUID-based) and scoped to the shell provider instance — tasks cannot be accessed from a different agent or a different process.

`rust:hexdump` — binary data inspection. Exposes a single `hexdump(data)` tool that renders base64-encoded binary data as a color-coded hex + ASCII dump. Pass the bytes as a base64 string (e.g. read the file with a binary-capable tool and encode before calling). Useful for agents inspecting binary formats, protocol captures, or serialized data.

```objectscript
Do agent.ToolManager.AddTool("rust:hexdump")
```

#### Tool Policies

:warning: advanced / experimental feature -- this capability may change significantly before GA release

**Setting Policies:**

```objectscript
// Authorization policy
Do agent.ToolManager.SetAuthPolicy(##class(%AI.Policy.ConsoleAuth).%New())

// Audit policy
Do agent.ToolManager.SetAuditPolicy(##class(%AI.Policy.ConsoleAudit).%New())
```

**Discovery policies — control which tools the LLM sees:**

A `%AI.Policy.Discovery` subclass filters or extends the tool catalog at runtime before it is sent to the LLM. Override `%Resolve()` to modify the catalog in place, and `%Execute()` to handle execution of any tools your policy introduces:

```objectscript
Class MyApp.RoleBasedDiscovery Extends %AI.Policy.Discovery
{
    Property UserRole As %String;

    /// Remove tools the current role is not allowed to see.
    Method %Resolve(catalog As %DynamicArray) As %Status
    {
        // Iterate backwards so removing an element does not shift unvisited indices.
        Set i = catalog.%Size() - 1
        While i >= 0 {
            Set spec = catalog.%Get(i)
            If (..UserRole '= "admin") && (spec.metadata.%Get("admin_only") = "1") {
                Do catalog.%Remove(i)
            }
            Set i = i - 1
        }
        Return $$$OK
    }
}

// Attach to the ToolManager
Set policy = ##class(MyApp.RoleBasedDiscovery).%New()
Set policy.UserRole = currentUser.Role
Do agent.ToolManager.SetDiscoveryPolicy(policy)
```

The `%Execute()` method is called when the LLM invokes a tool that your policy introduced via `%Resolve()`. Return `$$$NULLOREF` if the tool name is not recognised by this policy (the framework falls through to the normal registry); return a `%DynamicObject` result on success. The default implementation returns `$$$NULLOREF`.

**Smart Discovery (RAG-based tool selection):**

Enable Smart Discovery to let the framework automatically select the most relevant tools from a large registry based on the user's message. Tools are embedded and retrieved via semantic similarity, so the LLM only sees the handful most likely to be useful — keeping the prompt focused and reducing noise:

```objectscript
// Enable Smart Discovery (replaces any manual discovery policy)
$$$ThrowOnError(agent.ToolManager.EnableSmartDiscovery())
```

Smart Discovery embeds tool descriptions on registration and retrieves the closest matches at query time. It requires the fast-embed feature to be active and works best with registries of 20+ tools where most are not relevant to any given query.


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

### %AI.Catalog - Asset Discovery

`%AI.Catalog` provides design-time discovery of all `%AI` assets (skills, toolsets, tools, agents) defined in the current namespace. It queries `%Dictionary.CompiledClass` directly — no registration step is required; defining a subclass is sufficient.

All methods accept an optional `pattern` argument (SQL `LIKE` syntax, e.g. `"MyApp.%"`) and return a `%Library.DynamicArray` of `%DynamicObject` entries.

```objectscript
// List all skills
Set skills = ##class(%AI.Catalog).Skills()
Set iter = skills.%GetIterator()
While iter.%GetNext(.key, .entry) {
    Write entry.name, " — ", entry.description, !
    If entry.tools '= "" { Write "  tools: ", entry.tools, ! }
}

// Scope to a package
Set myTools = ##class(%AI.Catalog).Tools("MyApp.%")
Set mySets  = ##class(%AI.Catalog).ToolSets("MyApp.%")
Set myAgents = ##class(%AI.Catalog).Agents("MyApp.%")

// Find a single entry by class name (returns type + metadata, or "" if not found)
Set entry = ##class(%AI.Catalog).Find("MyApp.Skill.CreatePR")
Write entry.type, ": ", entry.name, !   // skill: MyApp.Skill.CreatePR
```

| Method | Discovers | Key fields |
|--------|-----------|------------|
| `Skills(pattern)` | Subclasses of `%AI.Agent.Skill` | `name`, `description`, `tools` |
| `ToolSets(pattern)` | Subclasses of `%AI.ToolSet` | `name`, `description` |
| `Tools(pattern)` | Subclasses of `%AI.Tool` (excludes ToolSets and SubAgents) | `name`, `description` |
| `Agents(pattern)` | Subclasses of `%AI.Agent` | `name`, `description` |
| `Find(name)` | Any of the above by exact class name | adds `type` field |

For skills, `description` comes from `Parameter DESCRIPTION` when set, falling back to the class comment. Abstract, hidden, and system classes are excluded from all queries.

---


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

Each typed parameter becomes a JSON Schema property. Parameters without a default value are marked required. Supported types: `%String`, `%Integer`, `%Float`, `%Boolean`, `%Binary`, `%DynamicObject`, `%DynamicArray`, and any `%JSON.Adaptor` subclass.

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
| `%Binary` | `{"type": "string", "contentEncoding": "base64"}` |
| `%Stream.GlobalCharacter` | `{"type": "string"}` |
| `%Stream.GlobalBinary` | `{"type": "string", "contentEncoding": "base64"}` |

`%Binary` parameters are automatically base64-decoded from the caller's input before your method is invoked. `%Binary` return values are automatically base64-encoded before delivery to the caller. Your method works with raw bytes; the framework handles the encoding on both sides.

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

> **Note:** Full class-type schema generation applies to plain `%AI.Tool` subclasses (auto-discovered method tools). Tools declared in a ToolSet XML `<Tool/>` element use a simplified schema (string/number/boolean only), since the ToolSet compiler does not have visibility into the class hierarchy at compile time. For tools with complex object parameters, prefer a plain `%AI.Tool` subclass. For SQL-only tools that need only scalar parameters, the ToolSet `<Query>` element is a good fit — it derives its schema from the `Arguments` attribute and returns the standard result envelope automatically.


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

### Method 5: Query-as-Tool

Class queries defined on a `%AI.Tool` subclass are automatically discovered and exposed
as callable tools. No extra dispatch code is needed — `%Discover()` enumerates both
methods and queries, and `%Invoke()` handles both at runtime.

**When to use:** read-heavy operations that are naturally expressed as SQL queries, where
you want column-level metadata in the return schema (via `ROWSPEC`) and a standard result
envelope with row count and truncation flag.

```objectscript
Class Sample.AI.Tools.ClassBrowser Extends %AI.Tool
{

XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# IRIS Class Browser

Search and browse IRIS class definitions in the current namespace.

**Pattern** uses SQL LIKE syntax: `%` matches any sequence of characters,
`_` matches one character. Leave empty or omit to return all classes.
Examples: `Sample.%` (all Sample classes), `%Tool%` (classes with Tool in the name).

**ClassType** narrows by kind. Values: `datatype`, `persistent`, `serial`,
`registered`, `stream`, `view`. Leave empty or omit to include all types.
}

/// Search IRIS class definitions by name pattern and optional class type.
/// Pattern: SQL LIKE syntax, e.g. "Sample.%", "%Tool%". Empty = all classes.
/// ClassType: filter by kind -- datatype, persistent, serial, registered. Empty = all.
Query Search(
    Pattern As %String = "",
    ClassType As %String = "") As %SQLQuery(
    ROWSPEC = "Name:%String,ClassType:%String,Abstract:%Boolean,Description:%String") [ SqlProc ]
{
    SELECT Name, ClassType, CASE WHEN Abstract = 1 THEN 1 ELSE 0 END AS Abstract, Description
    FROM %Dictionary.ClassDefinition
    WHERE Name LIKE CASE WHEN :Pattern = '' THEN '%' ELSE :Pattern END
      AND (:ClassType = '' OR ClassType = :ClassType)
    ORDER BY Name
}

}
```

**How the framework handles queries:**

- **Discovery:** `%Discover()` enumerates class queries after methods. Each query becomes
  a tool spec tagged with `"kind": "query"` in its metadata.
- **Parameters:** The query formalspec is parsed exactly like a method formalspec. Each
  parameter becomes a JSON Schema property; parameters without a default are marked
  required.
- **Return schema:** Built from `ROWSPEC`. Each `Name:Type` segment becomes a typed column
  in the `rows` array schema.
- **Execution:** `%Invoke(queryName, args)` uses `%SQL.Statement.%PrepareClassQuery` +
  `%Execute`, streaming up to `QUERYMAXROWS` rows (class parameter, default 100).
- **Result envelope:** Always `{"rows": [...], "row_count": N, "truncated": bool, "elapsed_ms": N}`.
  The LLM can use `truncated: true` as a signal to narrow the query.

**Notes:**

- Handle the "parameter not supplied" case in SQL, not in the default value. The agent
  passes arguments from the LLM directly; ObjectScript query parameter defaults are not
  applied by the dispatch layer. The pattern `CASE WHEN :Param = '' THEN '%' ELSE :Param END`
  handles an absent or empty argument correctly.
- Use `CASE WHEN bitCol = 1 THEN 1 ELSE 0 END` instead of `COALESCE(bitCol, 0)` for BIT
  columns — IRIS SQL rejects implicit BIT/INTEGER conversions in COALESCE.
- Use `%SQLQuery` with `[ SqlProc ]`. Other query types (`%Query`) are not supported by
  the dispatch layer.
- The `QUERYMAXROWS` parameter can be overridden per class:
  ```objectscript
  Parameter QUERYMAXROWS As INTEGER = 500;
  ```


### Tool Class Parameters

`%AI.Tool` (and by extension `%AI.ToolSet`) supports several class-level parameters that control discovery, authorization, and statefulness.

#### `REQUIRESAUTH` — mark a class as requiring authorization

Set `REQUIRESAUTH = 1` to require that every tool in the class be explicitly approved by an authorization policy before it executes. This is the class-level equivalent of attaching `RequiresAuth` per-tool — use it for any class whose methods perform destructive or mutating operations:

```objectscript
Class MyApp.DatabaseAdmin Extends %AI.Tool
{
    /// All tools in this class require authorization policy approval.
    Parameter REQUIRESAUTH As BOOLEAN = 1;

    /// Drop a database table. Requires explicit admin authorization.
    ClassMethod DropTable(tableName As %String) As %String { ... }

    /// Truncate all rows. Requires explicit admin authorization.
    ClassMethod TruncateTable(tableName As %String) As %String { ... }
}
```

Without an authorization policy that explicitly allows the call, any tool in this class returns an access-denied error. This provides a hard safety gate independent of which agent or prompt is calling the tool.

#### `DISCOVERYLIMIT` — prevent inherited methods from leaking

When you extend a base class that has its own methods, `%AI.Tool` discovers all public methods in the class hierarchy by default. Set `DISCOVERYLIMIT` to the class where tool discovery should stop:

```objectscript
Class MyApp.Derived Extends MyApp.Base
{
    /// Only expose tools defined on MyApp.Derived and its subclasses.
    /// Methods from MyApp.Base and above are not included.
    Parameter DISCOVERYLIMIT = "MyApp.Derived";

    ClassMethod MyNewTool() As %String { ... }
}
```

This is particularly important when extending framework classes (`%AI.MCP.Service`, etc.) that have many internal methods — without `DISCOVERYLIMIT` those infrastructure methods appear as tools.

#### `STATEFUL` — override automatic statefulness detection

By default, ClassMethods are marked as stateless (no session affinity required) and instance Methods are marked as stateful. Set `STATEFUL = 1` when ClassMethods access shared mutable state — globals, process-private globals, or external state — and therefore require a persistent session connection:

```objectscript
Class MyApp.GlobalCounter Extends %AI.Tool
{
    /// This class uses globals, so all tools require session affinity.
    Parameter STATEFUL As BOOLEAN = 1;

    ClassMethod Increment(by As %Integer = 1) As %Integer
    {
        Set ^MyApp.Counter = $GET(^MyApp.Counter) + by
        Return ^MyApp.Counter
    }
}
```


### Advanced: Custom Codec Hooks

:warning: advanced / experimental feature -- this capability may change significantly before GA release

Every `%AI.Tool` subclass (including `%AI.ToolSet`) has two overrideable instance methods that control how complex arguments are decoded from the LLM and how return values are encoded before being sent back.

#### `%Decode` — inbound argument decoding

Called by the generated `%Invoke` body when a parameter is typed to a concrete IRIS class (not a scalar, `%DynamicObject`, `%DynamicArray`, or collection). The default implementation creates a new instance of `cls` and populates it from the incoming JSON value using `%ToObject`.

```objectscript
Method %Decode(
    toolname As %String,   // name of the tool being invoked
    argname  As %String,   // name of the argument being decoded
    cls      As %String,   // fully-qualified target class name
    input    As %Any       // raw JSON value from the LLM (%DynamicObject)
) As %Any
```

Override this to add pre-processing, validation, or per-tool dispatch:

```objectscript
Method %Decode(toolname As %String, argname As %String, cls As %String, input As %Any) As %Any
{
    // Log all inbound complex arguments
    Do ##class(MyApp.ToolLog).LogArg(toolname, argname, input.%ToJSON())

    // Delegate to default behaviour
    Return ##super(toolname, argname, cls, input)
}
```

You can also dispatch per-tool to apply custom mapping for one specific tool without affecting others:

```objectscript
Method %Decode(toolname As %String, argname As %String, cls As %String, input As %Any) As %Any
{
    If toolname = "PlaceOrder" && argname = "item" {
        // Custom mapping: LLM sends "sku" but the class property is "ProductCode"
        Set obj = ##class(MyApp.OrderItem).%New()
        Set obj.ProductCode = input.sku
        Set obj.Quantity    = input.qty
        Return obj
    }
    Return ##super(toolname, argname, cls, input)
}
```

#### `%Encode` — outbound return value encoding

Called by the generated `%Invoke` body after the tool method returns. The default implementation passes scalars and `%DynamicObject`/`%DynamicArray` values through unchanged; IRIS objects are serialised to `%DynamicObject` via `%FromObject`.

```objectscript
Method %Encode(
    toolname As %String,   // name of the tool that was invoked
    rv       As %Any       // raw return value from the tool method
) As %Any
```

Override this to post-process or reshape return values:

```objectscript
Method %Encode(toolname As %String, rv As %Any) As %Any
{
    // Wrap the result in an envelope that includes metadata
    Set encoded = ##super(toolname, rv)
    If $ISOBJECT(encoded) && encoded.%IsA("%Library.DynamicAbstractObject") {
        Return {"tool": (toolname), "result": (encoded), "ts": ($ZDATETIME($HOROLOG, 3))}
    }
    Return encoded
}
```

#### Scope

Both hooks receive the tool name, so a single override can handle all tools uniformly, branch per-tool, or delegate most cases to `##super`. Because `%AI.ToolSet` inherits from `%AI.Tool`, the same override pattern works in both plain tool classes and ToolSets.

### Building Agent Skills

> :information_source: **Skills** (including progressive-disclosure activation) and the built-in **Planning skill** (`%AI.Skills.Planning`) are experimental features. See the [Advanced Features Guide](ObjectScript_SDK_Advanced.md#skills-aiagentskill) for the full API and examples.

## Building ToolSets

ToolSets are collections of tools organized by domain or functionality. They support composition, filtering, and integration with external services.

### ToolSet Structure

Concretely, a ToolSet is an instance of `%AI.Toolset`. Custom ToolSets extend this superclass and have the following structure:
1. Inline tools
2. Included ToolSets
3. Included ToolSets with filtering
4. Inline SQL queries
5. MCP server (external tools)

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
            <!-- Match= is a POSIX regex; only matching tool names are included -->
            <Include Class="%AI.Tools.FileSystem" Match="^(read|list)"/>
            <!-- <Exclude> removes already-collected tools; Tool= is exact, Match= is regex -->
            <Exclude Class="%AI.Tools.FileSystem" Tool="delete_file"/>

            <!-- 4. Inline SQL Query -->
            <Query Name="FindRecentOrders"
                   Description="Find the most recent orders, optionally filtered by status."
                   Arguments="status As %String = ''"
                   MaxRows="20">
              SELECT ID, OrderDate, TotalAmount, Status
              FROM MyApp_Orders.Order
              WHERE (:status = '' OR Status = :status)
              ORDER BY OrderDate DESC
            </Query>

            <!-- 5. MCP Server (External Tools) -->
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

Compose ToolSets by including other `%AI.ToolSets` or plain `%AI.Tool` subclasses. When you include a class, you can attach `<Requirement>` elements — metadata that is stamped onto each imported tool's spec and can be read by authorization or audit policies.


```xml
<Include Class="%AI.Tools.SQL">
    <Requirement Name="ReadOnly" Value="1"/>
    <Requirement Name="Role" Value="%All"/>
</Include>
```

`<Include>` discovers tools by calling `%Discover()` on the included class at **compile time**. This means:

- For `%AI.ToolSet` subclasses: all tools defined in their XData block are imported (after their own Exclude filters are applied).
- For `%AI.Tool` subclasses: both methods **and class queries** are imported. A `%AI.Tool` subclass with `Query` methods (see [Method 5: Query-as-Tool](#method-5-query-as-tool)) exposes those queries as tools, and they appear in the including ToolSet just like method-based tools.

```xml
<!-- Include a %AI.Tool subclass that has both methods and class queries -->
<Include Class="Sample.AI.Tools.ClassBrowser"/>
<!-- The Search query tool is now available alongside any method tools -->
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


### Inline SQL Queries

A `<Query>` element in a ToolSet XData block declares an inline SQL query as a tool. The SQL is prepared and validated at **compile time**, typed parameters are derived from the `Arguments` attribute, and results are returned in the standard SQL result envelope.

**When to use:** SQL-first read operations where you want direct control over the query text, compile-time SQL validation, and automatic parameter schema generation — without writing an extra method or a separate class.

```objectscript
Class MyApp.ReportTools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="ReportTools">

  <Query Name="FindOrders"
         Description="Find orders for a customer, optionally filtered by status."
         Arguments="customerId As %Integer, status As %String = ''"
         MaxRows="50">
    <![CDATA[
      SELECT ID, OrderDate, TotalAmount, Status
      FROM MyApp_Orders.Order
      WHERE CustomerID = :customerId
        AND (:status = '' OR Status = :status)
      ORDER BY OrderDate DESC
    ]]>
  </Query>

</ToolSet>
}

}
```

#### `<Query>` attributes

| Attribute | Required | Description |
|---|---|---|
| `Name` | Yes | Tool name exposed to the LLM |
| `Description` | Recommended | Natural-language description for the LLM |
| `Arguments` | When SQL has parameters | Parameter declarations in ObjectScript syntax: `name As %Type = default, ...` |
| `MaxRows` | No | Maximum rows returned. Overrides the class-level `QUERYMAXROWS` parameter |

#### Writing the SQL

- Use named `:param` placeholders. Positional `?` placeholders are rejected.
- Every `:param` in the SQL must have a matching entry in `Arguments`, and vice versa.
- Use `<![CDATA[...]]>` when the SQL contains XML-reserved characters (`<`, `>`, `&`). Using a `--` sequence anywhere inside an XML comment is also illegal; prefer `:` or another separator.
- The SQL is prepared (and syntax-checked) at compile time. SQL errors prevent the class from compiling.

#### Parameter type mapping

The `Arguments` attribute uses ObjectScript parameter syntax. Type names map to JSON Schema:

| Argument type | JSON Schema type |
|---|---|
| `%Integer`, `%Numeric`, `%Double`, `%Float` | `number` |
| `%Boolean` | `boolean` |
| `%String`, `%Date`, `%Time`, `%TimeStamp` | `string` |

Parameters without a default value (`= ...`) are marked required in the schema.

#### Handling optional parameters

ObjectScript query parameter defaults are not applied at dispatch time. Handle optional parameters in the SQL itself using a `CASE` expression or an `OR` guard:

```xml
<Query Name="FindOrders" Arguments="status As %String = ''">
  SELECT ID, Status FROM MyApp.Order
  WHERE (:status = '' OR Status = :status)
</Query>
```

#### Result envelope

All `<Query>` tools return the standard SQL result envelope:

```json
{
  "rows":       [{"ID": 1, "OrderDate": "2025-01-15", "TotalAmount": 99.95}, ...],
  "row_count":  25,
  "truncated":  false,
  "elapsed_ms": 12
}
```

`truncated: true` means the result was capped by the row limit. The LLM can use this as a signal to narrow the query.

#### Row limits

The number of rows returned is capped in priority order:

1. The `MaxRows` attribute on the `<Query>` element (per-query override).
2. The `QUERYMAXROWS` class parameter (applies to all queries on the class; default 100).

```objectscript
Class MyApp.ReportTools Extends %AI.ToolSet
{
    /// Raise the default row cap for all queries on this class.
    Parameter QUERYMAXROWS = 500;

    XData Definition [ MimeType = application/xml ]
    {
    <ToolSet Name="ReportTools">

      <!-- Uses per-query MaxRows=10, ignoring QUERYMAXROWS -->
      <Query Name="TopSellers" MaxRows="10"
             Description="Return the 10 best-selling products this month.">
        SELECT Name, UnitsSold FROM MyApp.Product ORDER BY UnitsSold DESC
      </Query>

      <!-- Uses class-level QUERYMAXROWS=500 -->
      <Query Name="AllProducts"
             Description="List all products.">
        SELECT Name, Category, Price FROM MyApp.Product ORDER BY Name
      </Query>

    </ToolSet>
    }
}
```

#### Filtering `<Query>` tools

`<Query>` tools participate in `<Exclude>` filtering like any other tool. The `Name` attribute is matched:

```xml
<ToolSet Name="SafeReports">
  <Include Class="MyApp.ReportTools"/>
  <!-- Suppress a specific query by exact name -->
  <Exclude Tool="RawDataDump"/>
  <!-- Suppress all queries whose names start with Internal -->
  <Exclude Match="^Internal"/>
</ToolSet>
```


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

**Environment isolation.** Stdio child processes run with a clean environment — they do not inherit the IRIS process's environment, which would otherwise expose LLM API keys and other credentials to every MCP server. Any environment variable the server needs must be passed explicitly via `<Env>` elements (using literal values or `@{env.VAR}`, `@{wallet.path}` references). This is intentional: an MCP server should receive only what it is explicitly given.

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

Use `@{prefix.key}` placeholders to pull values from external sources at runtime. Three prefixes are available by default:

| Prefix | Source | Example |
|---|---|---|
| `env` | OS environment variable | `@{env.OPENAI_API_KEY}` |
| `wallet` | IRIS Secure Wallet | `@{wallet.AISecrets.OpenAIKey}` |
| `config` | InterSystems IRIS ConfigStore | `@{config.AI.LLM.ProductionLLM}` |

```xml
<MCP Name="APIServer">
    <Stdio Executable="/opt/servers/api-mcp">
        <Env Name="API_KEY" Value="@{wallet.AISecrets.ExternalAPIKey}"/>
    </Stdio>
</MCP>
```

#### `env` and `wallet`

```objectscript
// IRIS Secure Wallet (secrets — requires %Admin_Wallet:USE or CUSTOM usage)
Do ##class(%Wallet.KeyValue).Create("AISecrets.ExternalAPIKey", {
    "Secret": "sk-proj-...",
    "Usage": ["CUSTOM"]})

// Register the wallet and config stores (call once at startup)
Do ##class(%AI.Utils.SettingStore).RegisterDefaults()
```

#### `config` — InterSystems IRIS ConfigStore

The `config` prefix resolves named configurations from the InterSystems IRIS ConfigStore. The key is the fully qualified configuration name (`Area.Type[.Subtype].Name`). Short keys with fewer than three segments are automatically prefixed with `AI.LLM`:

- **Descriptor** — identifies which ConfigStore Descriptor your application has registered for the `AI.LLM` area/type
- **Name** — the name of the specific configuration instance

```objectscript
// Full FQN -- used as-is
Parameter PROVIDERCONFIG = "@{config.AI.LLM.ProductionLLM}";

// Short form -- AI.LLM is prepended automatically
Parameter PROVIDERCONFIG = "@{config.ProductionLLM}";

// With subtype
Parameter PROVIDERCONFIG = "@{config.AI.LLM.OpenAI.ProductionLLM}";
```

`##class(%ConfigStore.Configuration).GetDetails()` is called with `resolveSecrets=1`, so any secret references in the stored configuration are resolved to their actual values before being returned. The full JSON details object is used as the placeholder value.

**Prerequisite:** Reading a configuration requires a ConfigStore Descriptor to be registered for the relevant area/type. Refer to the [ConfigStore documentation](Config_Store_Guide.md) for details on creating and registering descriptors.

Expansion is performed by the Rust SettingExpander, so the same `@{...}` syntax works everywhere in the framework: ToolSet config, provider settings, and agent parameters.


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

`%AI.System.Shell()` launches a full interactive terminal session. It delegates to `%AI.Shell.Console.Run()`, which drives a `%AI.Shell.ConsoleAgent` — a pre-configured agent with shell tools, console authorization and audit policies, and a system prompt biased toward ObjectScript. It demonstrates:

- Provider initialization with flexible configuration
- Agent setup with tools and policies
- Session management across multiple turns
- Streaming output with visual feedback
- Command handling (/help, /tools, /stats, etc.)
- Error handling and recovery
- Markdown rendering and syntax highlighting

**Source:** `%AI.Shell.Console` (REPL loop), `%AI.Shell.ConsoleAgent` (agent behavior), `%AI.Shell.StreamRenderer` (terminal output).

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
