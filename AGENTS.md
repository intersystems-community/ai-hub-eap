# AI Hub EAP — Agent Guide

## What Is InterSystems AI Hub?

InterSystems AI Hub is an IRIS-native AI platform that ships as a set of `%AI.*` ObjectScript
classes, a Rust binary (`iris-mcp-server`), and a Python/LangChain SDK. It lets you:

1. **Build agents in ObjectScript** using `%AI.ToolSet`, `%AI.Agent`, and `%AI.Policy.*`
   classes that run directly on IRIS with full RBAC enforcement.
2. **Expose IRIS business logic to external agents** via `iris-mcp-server` — a standalone MCP
   gateway that connects LLM clients (Claude Desktop, remote MCP clients) to IRIS endpoints
   without requiring a web server.
3. **Operationalize LangChain apps** via `langchain-iris` — store LLM and MCP server
   credentials in the IRIS Config Store, enforce RBAC, and access IRIS Vector Search from
   Python.

**Current build: 2026.2.0AI.162** (NoPWS — see [Container Notes](#container-notes) below).

---

## Where to Look

| Topic                                                        | Location                          |
| ------------------------------------------------------------ | --------------------------------- |
| ObjectScript API (`%AI.*` classes, ToolSet, Agent, Policy)   | `objectscript/`                   |
| MCP server guide (config, transports, auth, troubleshooting) | `MCP_Server_Guide.md`             |
| MCP server examples                                          | `MCP_Server_Examples.md`          |
| LangChain SDK (`ChatIRIS`, vector store, `init_chat_model`)  | `langchain/` + `langchain_SDK.md` |
| Config Store (`%ConfigStore.Configuration`, Wallet)          | `Config_Store_Guide.md`           |
| ObjectScript examples (runnable sample classes)              | `ObjectScript_SDK_Examples.md`    |
| ObjectScript SDK guide (full API reference)                  | `ObjectScript_SDK_Guide.md`       |
| ObjectScript advanced features                               | `ObjectScript_SDK_Advanced.md`    |

---

## AI Agent Workflows

### Build an ObjectScript Agent

```objectscript
Class MyApp.AI.MyAgent Extends %AI.Agent
{
    Parameter PROVIDER  = "openai";
    Parameter MODEL     = "gpt-4o";
    Parameter APIKEY;                         // empty → reads OPENAI_API_KEY from env
    Parameter TOOLSETS  = "%AI.Tools.SQL";   // comma-separated toolset class names

    XData INSTRUCTIONS [ MimeType = text/markdown ]
    {
    You are a helpful IRIS database assistant.
    }
}

// Usage:
Set agent = ##class(MyApp.AI.MyAgent).%New()
$$$ThrowOnError(agent.%Init())               // REQUIRED — wires provider, tools, prompt
Set session = agent.CreateSession()
Set response = agent.Chat(session, "How many patients are in the database?")
Write response.Content
```

Key classes:

- `%AI.Agent` — execution engine; subclass declaratively or instantiate programmatically
- `%AI.ToolSet` — compose tools + policies via XData XML DSL
- `%AI.Tool` — base class for individual tool implementations
- `%AI.Policy.ConsoleAudit` — log all tool calls to the console (terminal/agent code only, not MCP)
- `%AI.Policy.Authorization` — fine-grained per-tool authorization based on claims

`%AI.Policy.ConsoleAudit` writes to the current device. In a toolset exposed over MCP the current device is the HTTP response body, so it corrupts the JSON-RPC reply and every `tools/call` fails with a JSON parse error. For MCP, subclass `%AI.Policy.Audit` and write to a persistent class instead.

### Expose IRIS Tools via MCP

1. Create an MCP service class:

   ```objectscript
   Class MyApp.MCP.MyService Extends %AI.MCP.Service
   {
       Parameter SPECIFICATION As STRING = "MyApp.ToolSet.Database";
   }
   ```

2. Register it in the Management Portal:
   **System Administration → Security → Applications → MCP Servers**
   Set **Dispatch Class** to `MyApp.MCP.MyService`.

3. Write a minimal `config.toml` and start the binary:

   ```toml
   [mcp]
   transport = "stdio"

   [[iris]]
   name   = "local"
   server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
   pool   = { min = 2, max = 5 }
   endpoints = [{ path = "/mcp/myapp" }]

   [logging]
   level  = "info"
   output = "file"
   file   = "iris-mcp.log"
   ```

   ```bash
   iris-mcp-server --config=config.toml run
   ```

4. Point Claude Desktop at the binary in `claude_desktop_config.json`.

See `MCP_Server_Guide.md` for the full config reference, transport modes (stdio / HTTP / HTTPS),
OAuth 2.1 AS proxy, HashiCorp Vault integration, and troubleshooting.

### Use LangChain

```bash
pip install langchain-iris   # or install from the .whl on the EAP portal
```

```python
from langchain_intersystems.chat_models import init_chat_model
from langchain_intersystems import init_mcp_client

llm = init_chat_model("AI.LLM.myconfig")    # ConfigStore entry name
mcp = init_mcp_client("AI.MCP.my-server")
```

See `langchain_SDK.md` for `ChatIRIS`, IRIS Vector Store, and credential configuration.

### Work on ObjectScript Classes with `iad`

Build 162 is NoPWS — Atelier REST is unavailable. Use `iris-agentic-dev` (`iad`) in
`docker_only=true` mode:

```toml
# .iris-agentic-dev.toml
[container]
docker_only = true
name        = "aihub-iris-116"
port        = 21972
```

Compile and execute via `iad`:

```bash
iad iris_compile MyApp.MyClass
iad iris_execute "Write ##class(MyApp.MyClass).SomeMethod()"
```

Use `iris-devtester` `attach()` for container lifecycle management.

---

## Key API Facts — Build 162

### `LLMConfig` is gone

`LLMConfig` was removed before build 159. **Never use it.**

```objectscript
// ❌ Dead code — throws <PROPERTY DOES NOT EXIST>:
Set agent.LLMConfig = "AI.LLM.openai"

// ✅ Correct: declarative Parameters + %Init()
Set agent = ##class(MyApp.AI.MyAgent).%New()
$$$ThrowOnError(agent.%Init())
```

### `%Init()` is required

Always call `%Init()` before the first `Chat()`. Without it, the provider and tools are not
wired and the call will fail.

### `%AI.Provider.Create` pattern

```objectscript
// Programmatic provider (for dynamic selection):
Set provider = ##class(%AI.Provider).Create("anthropic", {"api_key": apiKey})
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "claude-sonnet-5"
```

Supported provider names: `"openai"`, `"anthropic"`, `"bedrock"`, `"vertex"`, `"gemini"`,
`"xai"` (alias: `"grok"`), `"nim"`.

### `@{}` credential substitution

Available in `PROVIDERCONFIG` parameters and ToolSet XData — **not** in ObjectScript code.

| Syntax              | Source                  |
| ------------------- | ----------------------- |
| `@{env:VAR}`        | OS environment variable |
| `@{config:Key}`     | `^%AI.Config` global    |
| `@{wallet:Col.Key}` | IRIS Secure Wallet      |

### ConfigStore production pattern

```objectscript
// Store (run once to seed):
Set config = {
    "model_provider": "anthropic",
    "model": "claude-sonnet-5",
    "api_key": "secret://AISecrets.anthropic#apikey"
}
Do ##class(%ConfigStore.Configuration).Create("AI","LLM","","myconfig", config)

// Retrieve with secret resolution (resolveSecrets=1):
Set sc = ##class(%ConfigStore.Configuration).GetDetails(
    "AI.LLM.myconfig", .details, 0, 1)
Set provider = ##class(%AI.Provider).Create(details."model_provider", details)
Set model = details."model"
```

See `Config_Store_Guide.md` for full Wallet setup and RBAC configuration.

### Response object

```objectscript
Write response.Content              // %String — assistant's text reply
// response.ToolCalls               // %DynamicArray — tool call requests
// response.Usage                   // %DynamicObject — prompt_tokens, completion_tokens
// ❌ response.%Get("content")      // throws <METHOD DOES NOT EXIST>
```

### Build 162 additions

Build 162 adds 13 new `%AI` classes vs build 161, including:

- RAG stack: `%AI.RAG.Embedding.*`, `%AI.RAG.KnowledgeBase`, `%AI.RAG.VectorStore.IRIS`
- MCP client in ToolSet XData: `<MCP><Remote .../>` consumes external MCP servers as local tools
- Built-in tools: `%AI.Tools.FileSystem`, `%AI.Tools.ShellTools`, `%AI.Tools.SQL`
- Agent composition: `%AI.Agent.Skill`, `%AI.Agent.SubAgent`, `%AI.Tool`, `%AI.Tool.Resolver`
- Config utilities: `%AI.Utils.ConfigStore`, `%AI.Utils.SettingStore`, `%AI.Utils.WalletStore`

`%AI.Utils.*` classes are community 162+ only — calling them on enterprise 161 throws
`<CLASS DOES NOT EXIST>`.

### Build 161 compile order (critical)

If you are on build 161, compile ToolSet classes last:

```objectscript
// ✅ Three-step pattern:
do $system.OBJ.LoadDir("/src/MyApp","k",,0)       // 1. load, no compile
do $system.OBJ.CompilePackage("MyApp","ck")        // 2. compile all
do $system.OBJ.Compile("MyApp.ToolSet","ck")       // 3. recompile ToolSet last
```

---

## Container Notes

All 2026.2.0AI builds are **NoPWS** (DPP-1192): the private web server on port 52773 is
disabled. Atelier REST is not available. Port 52773 is dead.

**For ObjectScript development:** use `iris-agentic-dev` (`iad`) with `docker_only=true`.

**For MCP over HTTP:** `iris-mcp-server` uses the native wgproto super-server (port 1972) —
no web gateway required. HTTP tools and REST endpoints that rely on CSP/IRIS web gateway
are not available on the NoPWS builds.

**Linux volume permissions:** IRIS containers run as UID 51773 (`irisowner`). On Linux,
bind-mount directories must grant write access to UID 51773:

```bash
setfacl -R -m u:51773:rwX <repo-dir>
setfacl -R -d -m u:51773:rwX <repo-dir>
```

---

## Agent Skills

Load the `aihub-eap` skill from this repo for accurate build 162 API patterns. It contains
verified code for `%AI.Agent`, `%AI.Provider.Create`, ConfigStore, breaking changes from
build 141, and known build 159/161/162 gotchas.

```text
skills/aihub-eap/SKILL.md
```
