# iris-mcp-server User Guide

This guide covers how to install, configure, and run **iris-mcp-server** to expose IRIS tools to LLM clients via the Model Context Protocol (MCP).

For detailed information about creating tools and toolsets in ObjectScript, see the [ObjectScript USER_GUIDE](objectscript/USER_GUIDE.md).

## Table of Contents

- [iris-mcp-server User Guide](#iris-mcp-server-user-guide)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Quick Start](#quick-start)
    - [1. Create IRIS Backend](#1-create-iris-backend)
    - [2. Configure MCP Server](#2-configure-mcp-server)
    - [3. Run iris-mcp-server](#3-run-iris-mcp-server)
    - [4. Configure Claude Desktop](#4-configure-claude-desktop)
  - [Architecture](#architecture)
    - [Protocol Stack](#protocol-stack)
    - [Protocol Flow](#protocol-flow)
  - [Configuration](#configuration)
    - [Full TOML Reference](#full-toml-reference)
    - [Secret References](#secret-references)
    - [CLI Flags](#cli-flags)
    - [Configuration Priority](#configuration-priority)
  - [Transport Modes](#transport-modes)
    - [stdio (Claude Desktop)](#stdio-claude-desktop)
    - [HTTP (Remote MCP)](#http-remote-mcp)
    - [HTTPS (Remote MCP with TLS)](#https-remote-mcp-with-tls)
    - [Local IRIS Auto-Discovery](#local-iris-auto-discovery)
  - [Security \& Credentials](#security--credentials)
    - [Layer 1 — Authenticating iris-mcp-server to IRIS](#layer-1--authenticating-iris-mcp-server-to-iris)
    - [Layer 2 — MCP Endpoint Credentials](#layer-2--mcp-endpoint-credentials)
    - [Remote MCP — OAuth Passthrough](#remote-mcp--oauth-passthrough)
    - [HashiCorp Vault Integration](#hashicorp-vault-integration)
    - [wgproto TLS (IRIS Connection)](#wgproto-tls-iris-connection)
    - [Server-Side TLS (Remote MCP Endpoint)](#server-side-tls-remote-mcp-endpoint)
  - [IRIS Backend Setup](#iris-backend-setup)
    - [Simple Tool](#simple-tool)
    - [ToolSet with Policies](#toolset-with-policies)
    - [MCP Service Class](#mcp-service-class)
    - [Configure MCP Server](#configure-mcp-server)
  - [Service Discovery](#service-discovery)
    - [How Discovery Works](#how-discovery-works)
    - [Tool Refresh](#tool-refresh)
    - [Endpoint Auto-Discovery](#endpoint-auto-discovery)
    - [Local IRIS Instance Auto-Discovery](#local-iris-instance-auto-discovery)
    - [Tool Namespacing](#tool-namespacing)
    - [Reconnection](#reconnection)
  - [The iris\_status Diagnostic Tool](#the-iris_status-diagnostic-tool)
  - [Smart Discovery (RAG)](#smart-discovery-rag)
  - [Monitoring \& Telemetry](#monitoring--telemetry)
    - [Logging](#logging)
    - [OpenTelemetry Tracing](#opentelemetry-tracing)
    - [Verifying Tool Discovery](#verifying-tool-discovery)
  - [Production Deployment](#production-deployment)
    - [Container](#container)
    - [Kubernetes](#kubernetes)
    - [Connection Pool Sizing](#connection-pool-sizing)
  - [Troubleshooting](#troubleshooting)
    - [Connection Failures](#connection-failures)
    - [Connected but No Tools Appear](#connected-but-no-tools-appear)
    - [Tool Not Found](#tool-not-found)
    - [Authentication Failures (403)](#authentication-failures-403)
    - [Secret Resolution Failures](#secret-resolution-failures)
    - [Debug Logging](#debug-logging)
  - [Next Steps](#next-steps)
  - [Migrating from v0.1 Config](#migrating-from-v01-config)

> **Installation:** `iris-mcp-server` is a standalone binary included in the `bin` directory of your IRIS installation. No installation step is required — copy or reference it directly.
>
> **Upgrading from v0.1?** The configuration file format changed in v2. See [Migrating from v0.1 Config](#migrating-from-v01-config) at the end of this guide.

---

## Overview

**iris-mcp-server** is a Rust-based MCP gateway that bridges LLM clients (Claude Desktop, remote MCP clients) to IRIS MCP Server endpoints, handling tool discovery and execution transparently.

```
┌─────────────────────┐
│   Claude Desktop    │  (LLM Client)
│   or other MCP      │
│   compatible client │
└──────────┬──────────┘
           │ MCP Protocol (stdio or HTTPS streaming)
           ▼
┌─────────────────────┐
│  iris-mcp-server    │  (Rust binary)
│                     │
│  - MCP protocol     │
│  - Tool discovery   │
│  - Connection pool  │
│  - RAG discovery    │
└──────────┬──────────┘
           │ IRIS Web Gateway Protocol
           ▼
┌─────────────────────┐
│  %AI.MCP.Service    │  (IRIS ObjectScript)
│                     │
│  - Tool dispatch    │
│  - Policy layer     │
│  - ToolManager      │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│   Your Tools &      │
│   ToolSets          │
└─────────────────────┘
```

iris-mcp-server speaks the native Web Gateway Transport Protocol (wgproto), including over TLS, back to IRIS instance(s) — no external web server is required.

---

## Quick Start

### 1. Create IRIS Backend

Create an MCP service in IRIS (see [IRIS Backend Setup](#iris-backend-setup) for details):

```objectscript
Class MyApp.MCP.SimpleService Extends %AI.MCP.Service
{
    Parameter SPECIFICATION As STRING = "MyApp.Tools.Calculator";
}
```

### 2. Configure MCP Server

In the IRIS Management Portal create an MCP Server:
- **Name:** `/mcp/simple`
- **Dispatch Class:** `MyApp.MCP.SimpleService`
- **Authentication:** Password (or Unauthenticated for dev)

### 3. Run iris-mcp-server

**Using a config file (recommended):**

```powershell
iris-mcp-server.exe --config=config.toml run
```

**Minimal config.toml:**

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 5 }
endpoints = [
  { path = "/mcp/simple" },
]

[logging]
level  = "info"
output = "file"
file   = "iris-mcp.log"
```

### 4. Configure Claude Desktop

Add to `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "iris": {
      "command": "C:\\path\\to\\iris-mcp-server.exe",
      "args": [
        "--config=C:\\path\\to\\config.toml",
        "run"
      ]
    }
  }
}
```

Restart Claude Desktop. A gear icon appears when MCP servers are active. Claude logs are in `%APPDATA%\Claude\logs`.

---

## Architecture

### Protocol Stack

```
┌─────────────────────────┐
│  MCP Protocol           │  (JSON-RPC 2.0)
├─────────────────────────┤
│  iris-mcp-server        │  (Rust — protocol translation)
├─────────────────────────┤
│  STP Protocol           │  (JSON: request / response / error)
├─────────────────────────┤
│  wgproto                │  (IRIS native gateway protocol — binary)
├─────────────────────────┤
│  TCP                    │
└─────────────────────────┘
```

### Protocol Flow

**Tool discovery:**
```
LLM Client  →  MCP list_tools            →  iris-mcp-server
iris-mcp-server  →  wgproto GET /v1/services  →  IRIS
IRIS  →  ToolManager.%Discover()  →  JSON tool catalog
iris-mcp-server  →  MCP response         →  LLM Client
```

**Tool execution:**
```
LLM Client  →  MCP call_tool                    →  iris-mcp-server
iris-mcp-server  →  wgproto+ws /v1/ws           →  IRIS
IRIS  →  ToolManager.ExecuteTool()  →  (Auth → Execute → Audit)  →  result
result  →  STP response                          →  iris-mcp-server
iris-mcp-server  →  MCP response                →  LLM Client
```

---

## Configuration

### Full TOML Reference

```toml
# ── MCP Transport ─────────────────────────────────────────────────────────────
[mcp]
transport  = "stdio"        # stdio | http | https | sse
host       = "0.0.0.0"     # bind address for HTTP/HTTPS transports
port       = 8080           # bind port
base_route = "/mcp"         # HTTP route prefix (default: /mcp)

# TLS for the MCP HTTP transport (required when transport = "https")
# [mcp.tls]
# cert = "/etc/certs/server.crt"             # path to PEM certificate
# key  = "/etc/certs/server.key"             # path to PEM private key
# Secret references are also accepted:
# cert = "@{vault:tls/iris-mcp#certificate}"
# key  = "@{vault:tls/iris-mcp#private_key}"

# ── IRIS Servers ──────────────────────────────────────────────────────────────
# Use [[iris]] (double brackets) — one entry per IRIS instance.
# Multiple instances can be declared in the same file.

[[iris]]
name = "production"

# wgproto super-server connection credentials.
# Credential fields accept a literal value, @{env:VAR}, or @{vault:path#field}.
server = { host = "iris.example.com", port = 1972, username = "@{env:WG_USER}", password = "@{env:WG_PASS}" }

# WebSocket session pool for this instance.
pool = { min = 2, max = 10 }

# MCP endpoint paths on this IRIS instance.
# Each entry is an MCP Server path, with optional application-layer auth.
# Auth options per endpoint:
#   username + password  ->  HTTP Basic (Authorization: Basic ...)
#   bearer               ->  Bearer token (Authorization: Bearer ...)
#   (no auth fields)     ->  unauthenticated endpoint
endpoints = [
  { path = "/mcp/myapp" },
  { path = "/mcp/secure", username = "@{env:APP_USER}", password = "@{env:APP_PASS}" },
  { path = "/mcp/api",    bearer = "@{vault:iris/prod#api_token}" },
]

# Seconds between reconnect attempts when the connection is lost (default: 30)
reconnect_interval_secs = 30

# Seconds between tool-list refresh polls (default: 300)
tool_refresh_interval_secs = 300

# Maximum bytes to accumulate from IRIS for a single tool response (default: 10 MiB).
# Increase for tools that return very large payloads; decrease if your LLM has a
# small context window and is being overwhelmed by large results.
max_response_bytes = 10485760

# Seconds a pooled WebSocket session may sit idle before it is closed.
# Closing an idle session causes the IRIS job to Halt, freeing its license slot.
# Lower values free licenses faster; higher values reduce reconnection overhead.
# Default: 300 (5 minutes).
idle_timeout_secs = 300

# Maximum number of concurrent pooled sessions per (endpoint, auth_context) pair.
# Each OAuth user or opaque token gets its own pool up to this limit.
# Prevents runaway license consumption when many distinct identities are active.
# Default: same as pool.max.
max_sessions_per_auth_context = 10

# Hard cap on total session lifetime in seconds, regardless of activity.
# When set, a session older than this is dropped the next time it becomes idle
# (IRIS job Halts, license freed). Off by default — only idle_timeout_secs applies.
# Useful in high-churn environments to guarantee periodic license recycling.
# max_age_secs = 3600   # e.g. 1 hour

# TLS for the wgproto connection to this instance (optional).
# Presence of the tls field enables TLS; absence means plaintext.
# tls = {}                                         # system CA roots
# tls = { ca_cert = "/etc/certs/iris-ca.crt" }    # custom CA
# tls = { ca_cert = "/etc/certs/iris-ca.crt",      # mutual TLS
#          cert    = "/etc/certs/client.crt",
#          key     = "/etc/certs/client.key" }

# ── Secret Provider ──────────────────────────────────────────────────────────
[secrets]
provider = "env"            # env | vault  (default: env)

# Required only when provider = "vault":
# vault_addr       = "http://127.0.0.1:8200"
# vault_token      = "s.xxxx"                # literal token
# vault_token_file = "/var/run/vault/token"  # or path to token file
# vault_mount      = "secret"                # KV v2 mount (default: secret)

# ── Logging ──────────────────────────────────────────────────────────────────
[logging]
level  = "info"             # error | warn | info | debug | trace
output = "stderr"           # stderr | file
# file = "/var/log/iris-mcp.log"   # required when output = "file"

# ── Optional Feature Toggles ─────────────────────────────────────────────────
[features]
smart_discovery = false     # enable RAG tool search (requires smart-discovery feature)
telemetry       = false     # enable OpenTelemetry tracing
vault           = false     # enable Vault secret provider
```

### Secret References

Any credential field (`username`, `password`, `bearer`, `cert`, `key`, etc.) accepts one of three formats:

| Format | Example | How it resolves |
|--------|---------|-----------------|
| **Literal** | `"CSPSystem"` | Used exactly as written |
| **Environment variable** | `"@{env:IRIS_PASS}"` | Reads `$IRIS_PASS` at startup |
| **Vault KV2** | `"@{vault:iris/prod#password}"` | Fetches from Vault: path `<mount>/iris/prod`, field `password` |

To include a literal `@{` in a value, escape it as `@@{`.

The Vault format is `@{vault:path#field}` where `path` is relative to the configured `vault_mount`. Vault is only available when built with the `vault` feature and `[secrets] provider = "vault"` with `vault_addr` configured.

### CLI Flags

All flags before the subcommand are global:

| Flag | Description |
|------|-------------|
| `--transport=<spec>` | `stdio`, `http://host:port`, `https://host:port`, `sse://host:port` |
| `--config=<path>` | Path to TOML configuration file |
| `--log-level=<level>` | `error` / `warn` / `info` / `debug` / `trace` (default: `info`) |
| `--log-output=<out>` | `stderr` / `file` (default: `stderr`) |
| `--log-file=<path>` | Log file path — required when `--log-output=file` |
| `--http-tls-cert=<path>` | Server TLS certificate (PEM) — required with `https://` |
| `--http-tls-key=<path>` | Server TLS private key (PEM) — required with `https://` |
| `--http-base-route=<path>` | HTTP route prefix (default: `/mcp`) |

`run` subcommand flags (all optional; override the `[[iris]]` config):

| Flag | Description |
|------|-------------|
| `--iris-host=<host>` | IRIS hostname or IP |
| `--iris-port=<port>` | IRIS super-server port |
| `--iris-user=<user>` | IRIS connection username |
| `--iris-password=<pass>` | IRIS connection password |
| `--iris-endpoint=<path>` | MCP endpoint path — may be repeated for multiple endpoints |
| `--auto-discover-interval=<secs>` | Poll for local IRIS instances every N seconds (0 = disabled) |
| `--status-tool=<bool>` | Expose `iris_status` diagnostic tool (default: `true`) |

### Configuration Priority

When the same value is specified in multiple places, the highest-priority source wins:

```
CLI flags  >  TOML config file  >  built-in defaults
```

Credentials in the TOML file are not overridden by environment variables directly — instead, use `@{env:VAR}` references inside the TOML so that the environment variable is read at startup.

---

## Transport Modes

### stdio (Claude Desktop)

```powershell
iris-mcp-server.exe --config=config.toml run
```

```toml
[mcp]
transport = "stdio"

[logging]
output = "file"
file   = "C:\\logs\\iris-mcp.log"
```

> When using stdio transport, set `output = "file"` so logs do not mix with the MCP protocol stream on stderr.

### HTTP (Remote MCP)

```powershell
iris-mcp-server.exe --transport=http://0.0.0.0:8080 --config=config.toml run
```

```toml
[mcp]
transport = "http"
host      = "0.0.0.0"
port      = 8080
```

### HTTPS (Remote MCP with TLS)

```powershell
iris-mcp-server.exe --transport=https://0.0.0.0:8443 --config=config.toml run
```

```toml
[mcp]
transport = "https"
host      = "0.0.0.0"
port      = 8443

[mcp.tls]
cert = "/etc/certs/server.crt"
key  = "/etc/certs/server.key"
```

TLS cert and key can also be supplied from Vault — see [Server-Side TLS](#server-side-tls-remote-mcp-endpoint).

### Local IRIS Auto-Discovery

When `--auto-discover-interval` is set, iris-mcp-server polls for locally-running IRIS instances (via `iris qlist` on Linux/Mac, or the Windows Registry) and automatically connects to any that appear:

```powershell
iris-mcp-server.exe --transport=http://0.0.0.0:8080 --config=config.toml run --auto-discover-interval=60
```

---

## Security & Credentials

iris-mcp-server has two independent authentication layers that serve different purposes:

| Layer | What it secures | Where configured |
|-------|-----------------|-----------------|
| **IRIS server auth** | iris-mcp-server connecting to the IRIS server | `[[iris]] server.username` / `server.password` |
| **MCP endpoint auth** | Per-request identity presented to each IRIS MCP endpoint | `[[iris]] endpoints[].username/password/bearer` |

Understanding both layers is essential — authenticating the connection to IRIS does **not** automatically authenticate individual requests to the MCP endpoint inside it.

### Layer 1 — Authenticating iris-mcp-server to IRIS

`server.username` and `server.password` authenticate iris-mcp-server to the IRIS server itself. These must be a privileged gateway user such as `CSPSystem` (the same credential that IIS/Apache web gateway modules use).

```toml
[[iris]]
name   = "local"
server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
```

These credentials are used once when the connection is established. For production, use secret references instead of literals:

```toml
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972,
           username = "@{env:IRIS_GW_USER}", password = "@{vault:iris/gateway#password}" }
```

> Never commit credentials to version control. Use `@{env:...}` references or Vault.

### Layer 2 — MCP Endpoint Credentials

Once connected to IRIS, each request targets a specific MCP endpoint — an MCP Server definition that maps a URL path to a `%AI.MCP.Service` subclass. If that endpoint requires authentication, IRIS returns **403 Forbidden** unless credentials accompany each request.

Credentials are configured per endpoint in the `endpoints` array:

```toml
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972, username = "@{env:WG_USER}", password = "@{env:WG_PASS}" }
pool   = { min = 2, max = 10 }
endpoints = [
  # Unauthenticated endpoint
  { path = "/mcp/public" },

  # HTTP Basic auth — sends Authorization: Basic base64(username:password)
  { path = "/mcp/secure", username = "@{env:APP_USER}", password = "@{env:APP_PASS}" },

  # Bearer token — sends Authorization: Bearer <token>
  { path = "/mcp/api", bearer = "@{vault:iris/prod#api_token}" },
]
```

**For Remote MCP (HTTP transport):** the `Authorization` header from the incoming MCP client session is automatically forwarded to IRIS per-request and takes priority over any configured endpoint credentials. See [OAuth Passthrough](#remote-mcp-oauth-passthrough).

**Choosing an auth mode:**

| Scenario | Configuration |
|----------|---------------|
| Remote MCP + OAuth Bearer tokens | Omit endpoint auth — the header is forwarded automatically |
| stdio transport (HTTP Basic) | `{ path = "...", username = "...", password = "..." }` |
| stdio transport (API key) | `{ path = "...", bearer = "..." }` |
| Unauthenticated endpoint | `{ path = "..." }` — set endpoint to *Unauthenticated* in IRIS |

> **Security:** Unauthenticated endpoints expose tools to anyone who can reach the IRIS server. Only use *Unauthenticated* during local development. All production environments should require authentication.

### Remote MCP — OAuth Passthrough

When iris-mcp-server runs in HTTP/HTTPS mode, each MCP session from a remote client carries its own `Authorization` header (commonly an OAuth 2.0 Bearer token). iris-mcp-server forwards the header value unchanged to IRIS on every request within that session. Any valid scheme (Bearer, API-key-as-Authorization, etc.) works without server-side changes.

OAuth passthrough is always active for the HTTP/HTTPS transport. Endpoint `username`/`password`/`bearer` configuration acts as a fallback only when no `Authorization` header arrives from the client.

### HashiCorp Vault Integration

Vault is available when built with the `vault` feature (included in the `gateway` and `full` presets).

**1. Configure the `[secrets]` section:**

```toml
[secrets]
provider         = "vault"
vault_addr       = "http://127.0.0.1:8200"
vault_token      = "@{env:VAULT_TOKEN}"         # token as env var reference
# vault_token_file = "/var/run/vault/token"     # or path to a token file
vault_mount      = "secret"                     # KV v2 mount name (default: "secret")

[features]
vault = true
```

> **Kubernetes:** use `vault_token_file` with a projected service account token volume rather than storing a static token in a Secret. The token is automatically rotated by Kubernetes and re-read by iris-mcp-server on the next startup.

**2. Reference Vault secrets in credential fields:**

```toml
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972,
           username = "@{vault:iris/gateway#username}",
           password = "@{vault:iris/gateway#password}" }
pool   = { min = 10, max = 50 }
endpoints = [
  { path = "/mcp/prod", bearer = "@{vault:iris/prod#app_token}" },
]
```

The path format is `@{vault:path#field}` where `path` is relative to `vault_mount`. For example, with `vault_mount = "secret"`, the reference `@{vault:iris/gateway#password}` reads the field `password` from the Vault KV2 secret at `secret/data/iris/gateway`.

**3. Set up the Vault secrets:**

```bash
# Enable KV v2 secrets engine (if not already enabled)
vault secrets enable -path=secret kv-v2

# Store IRIS gateway credentials
vault kv put secret/iris/gateway \
  username=CSPSystem \
  password=SYS

# Store IRIS application token
vault kv put secret/iris/prod \
  app_token=eyJ...
```

**4. Run with the token in the environment:**

```bash
export VAULT_TOKEN="s.xxxx"
iris-mcp-server --config=config.toml run
```

All secret references are resolved once at startup before any connections are established. If any secret fails to resolve, the server exits with an error.

### wgproto TLS (IRIS Connection)

To encrypt the wgproto connection between iris-mcp-server and IRIS, add a `tls` field to the `[[iris]]` entry. Presence of the field enables TLS — system certificate roots are used by default. The IRIS web gateway must also be configured for TLS.

```toml
# TLS with system roots — simplest form
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
tls    = {}
endpoints = [{ path = "/mcp/prod" }]

# TLS with a custom or self-signed IRIS CA certificate
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
tls    = { ca_cert = "/etc/certs/iris-ca.crt" }
endpoints = [{ path = "/mcp/prod" }]

# Mutual TLS — iris-mcp-server presents a client certificate to IRIS
[[iris]]
name   = "production"
server = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
tls    = { ca_cert = "/etc/certs/iris-ca.crt",
           cert    = "/etc/certs/client.crt",
           key     = "/etc/certs/client.key" }
endpoints = [{ path = "/mcp/prod" }]
```

Secret references are accepted in TLS fields:
```toml
tls = { ca_cert = "@{vault:tls/iris#ca_cert}" }
```

> `tls` on `[[iris]]` is for the **wgproto connection to IRIS** only. It is independent of `[mcp.tls]`, which covers the Remote MCP endpoint.

### Server-Side TLS (Remote MCP Endpoint)

TLS for the MCP HTTP transport endpoint is configured under `[mcp.tls]`:

```toml
# Both from files
[mcp.tls]
cert = "/etc/certs/server.crt"
key  = "/etc/certs/server.key"

# From Vault
[mcp.tls]
cert = "@{vault:tls/iris-mcp#certificate}"
key  = "@{vault:tls/iris-mcp#private_key}"
```

> `[mcp.tls]` secures the Remote MCP endpoint (LLM clients → iris-mcp-server). `[[iris]] tls` secures the wgproto connection (iris-mcp-server → IRIS). These are configured independently and may use different certificates.

---

## IRIS Backend Setup

### Simple Tool

```objectscript
Class MyApp.Tools.Calculator Extends %AI.Tool
{
    Method Add(a As %Integer, b As %Integer) As %Integer
    {
        Return a + b
    }

    Method Multiply(a As %Integer, b As %Integer) As %Integer
    {
        Return a * b
    }
}
```

### ToolSet with Policies

```objectscript
Class MyApp.ToolSet.Database Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="DatabaseTools">
            <Description>SQL and database operations</Description>
            <Policies>
                <Authorization Class="MyApp.Policy.ReadOnlyAuth" />
                <Audit Class="%AI.Policy.ConsoleAudit" />
            </Policies>
            <Include Class="%AI.Tools.SQL">
                <Requirement Name="ReadOnly" Value="1"/>
            </Include>
        </ToolSet>
    }
}
```

### MCP Service Class

```objectscript
Class MyApp.MCP.DatabaseService Extends %AI.MCP.Service
{
    /// SPECIFICATION lists tools, toolsets, or tool refs (comma-separated)
    Parameter SPECIFICATION As STRING = "MyApp.ToolSet.Database";
}
```

### Configure MCP Server

1. Open IRIS Management Portal
2. Navigate to: **System Administration → Security → Applications → MCP Servers**
3. Create a new application:
   - **Name:** `/mcp/database`
   - **Namespace:** USER
   - **Dispatch Class:** `MyApp.MCP.DatabaseService` (this is your `%AI.ToolSet` subclass)
   - **Enabled:** Yes
   - **Authentication:** Password (or Unauthenticated for dev/internal use)

---

## Service Discovery

### How Discovery Works

At startup iris-mcp-server fetches the tool list from each configured endpoint:

1. Sends `GET {endpoint}/v1/services` to IRIS (conditional GET with `If-None-Match` ETag)
2. IRIS MCP Service returns a JSON tool catalog
3. iris-mcp-server registers the tools, computing a per-tool SHA-256 hash
4. A service-level ETag is stored for future conditional GETs

### Tool Refresh

The background tool-refresh loop re-fetches tool lists every `tool_refresh_interval_secs` (default: 300 seconds). A 304 Not Modified response means no change and nothing is re-registered. On a 200 response, per-tool hashes are compared; only changed tools trigger an MCP `tools/list_changed` notification to connected clients.

```toml
[[iris]]
name                       = "dev"
server                     = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool                       = { min = 2, max = 5 }
tool_refresh_interval_secs = 60     # more frequent polling during development
endpoints                  = [{ path = "/mcp/myapp" }]
```

### Endpoint Auto-Discovery

If `endpoints` is omitted from `[[iris]]`, iris-mcp-server queries the IRIS CSP application registry for all apps matching `/mcp*` and connects to each one automatically.

```toml
[[iris]]
name   = "local"
server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 5 }
# endpoints omitted -> auto-discover /mcp* apps
```

### Local IRIS Instance Auto-Discovery

When `--auto-discover-interval=N` is set, the server polls for locally-running IRIS instances and connects to each one it finds. When an instance disappears its tools are deregistered.

### Tool Namespacing

When multiple MCP endpoints are connected, tools from each service are prefixed with a **service ID** derived from the endpoint path. This prevents name collisions and tells the LLM which service a tool belongs to.

The service ID is the endpoint path with the leading slash stripped and remaining slashes replaced with underscores:

| Endpoint path | Service ID prefix | Example tool name |
|---------------|-------------------|-------------------|
| `/mcp` | `mcp` | `mcp_ExecuteQuery` |
| `/mcp/database` | `mcp_database` | `mcp_database_ExecuteQuery` |
| `/mcp/myapp` | `mcp_myapp` | `mcp_myapp_GetCustomer` |

When there is only one endpoint, tools still carry the prefix. Keep this in mind when writing system prompts or instructions that refer to tools by name.

### Reconnection

If the connection to IRIS is lost (IRIS restart, network interruption), iris-mcp-server automatically attempts to reconnect in the background using the interval configured by `reconnect_interval_secs` (default: 30 seconds). You do not need to restart iris-mcp-server — tools remain registered and reconnection is retried silently until it succeeds.

```toml
[[iris]]
name                    = "dev"
server                  = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool                    = { min = 2, max = 5 }
reconnect_interval_secs = 10     # retry faster during development
endpoints               = [{ path = "/mcp/myapp" }]
```

---

## The iris_status Diagnostic Tool

When iris-mcp-server encounters connection errors or startup failures, it exposes a special MCP tool called **`iris_status`** that the LLM can call to report the problem. The tool only appears in the tool list when there are active errors — in a healthy, fully-connected session it is absent, keeping the tool list clean.

When the LLM sees `iris_status` it means something went wrong. Calling it returns a structured report of all current errors — for example:

```
iris_status result:
- mcp_database: connection failed — refused at localhost:1972
- mcp_analytics: authentication error — 403 Forbidden (check endpoint credentials)
```

This allows the LLM to proactively tell the user what is broken rather than silently failing when tools are called.

**To disable the tool entirely** (e.g. for a production environment where you don't want internal state visible to the LLM):

```powershell
iris-mcp-server.exe --config=config.toml run --status-tool=false
```

---

## Smart Discovery (RAG)

Smart discovery uses a local embedding model (fastembed / `AllMiniLML6V2`) to perform semantic search across all registered tool descriptions. When an LLM asks for tools matching a natural-language query, relevant tools are ranked by cosine similarity rather than exact name matching.

> The embedding model (~25 MB) is downloaded from HuggingFace on first use.

Enable in `config.toml`:

```toml
[features]
smart_discovery = true
```

Smart discovery is indexed automatically as tools are registered. No additional CLI flags are required.

---

## Monitoring & Telemetry

### Logging

Set the log level via CLI (overrides config):

```powershell
iris-mcp-server.exe --log-level=debug --log-output=stderr --config=config.toml run
```

Or in `config.toml`:

```toml
[logging]
level  = "debug"     # error | warn | info | debug | trace
output = "file"
file   = "C:\\logs\\iris-mcp.log"
```

For file output, `file` is required. For stderr output, `file` is ignored.

You can also set `RUST_LOG=debug` (or any `env_logger`-compatible filter) to override the log level from the environment.

### OpenTelemetry Tracing

Built with the `telemetry` feature (included in `gateway`). Traces are exported via OTLP (gRPC).

Enable in config:

```toml
[features]
telemetry = true
```

Set the OTLP endpoint via the standard environment variable:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
```

Run Jaeger for local trace visualization:

```bash
docker run -d --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  jaegertracing/all-in-one:latest
# View traces at http://localhost:16686
```

### Verifying Tool Discovery

The easiest way to confirm iris-mcp-server is discovering tools is to check the logs at startup:

```powershell
iris-mcp-server.exe --log-level=debug --config=config.toml run
```

Look for lines like `registered N tools from /mcp/database`. If no tools appear, enable debug logging and check for discovery errors.

If you have access to an IRIS web gateway (not the super-server port), you can also call the IRIS health endpoint directly:

```bash
curl http://<iris-webgateway-host>/mcp/database/v1/health
```

---

## Production Deployment

### Container

A pre-built container image is available. Run it with your config file mounted and credentials supplied via environment:

```bash
docker run -d \
  --name iris-mcp \
  -e WG_USER=CSPSystem \
  -e WG_PASS=SYS \
  -e VAULT_TOKEN=${VAULT_TOKEN} \
  -v /path/to/config.toml:/etc/iris-mcp/config.toml:ro \
  -p 8080:8080 \
  intersystems/iris-mcp-server:latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iris-mcp-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: iris-mcp-server
  template:
    metadata:
      labels:
        app: iris-mcp-server
    spec:
      containers:
      - name: iris-mcp-server
        image: iris-mcp-server:latest
        args: ["--config", "/etc/iris-mcp/config.toml", "run"]
        ports:
        - containerPort: 8080
        env:
        - name: VAULT_TOKEN
          valueFrom:
            secretKeyRef:
              name: vault-credentials
              key: token
        volumeMounts:
        - name: config
          mountPath: /etc/iris-mcp
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: iris-mcp-config
---
apiVersion: v1
kind: Service
metadata:
  name: iris-mcp-server
spec:
  selector:
    app: iris-mcp-server
  ports:
  - port: 8080
    targetPort: 8080
  type: LoadBalancer
```

### Connection Pool Sizing

Each IRIS instance has its own WebSocket session pool, sized by `pool = { min, max }`. Each pool slot is one WebSocket connection to IRIS — one concurrent tool call in flight per slot.

```toml
[[iris]]
name      = "production"
server    = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool      = { min = 5, max = 20 }    # up to 20 concurrent tool calls
endpoints = [{ path = "/mcp/prod" }]
```

Rule of thumb: `max` should be at least as large as the number of tool calls you expect to run simultaneously. `min` sets the number of sessions kept warm at idle.

**Session lifetime tuning** — each pooled session corresponds to one IRIS license slot (job). Three settings control how long sessions live:

| Setting | Default | Effect |
|---------|---------|--------|
| `idle_timeout_secs` | 300 | Close sessions idle longer than this; IRIS job Halts, license freed |
| `max_sessions_per_auth_context` | `pool.max` | Cap on concurrent sessions per OAuth user / token identity |
| `max_age_secs` | off | Hard cap on total session lifetime; session dropped on next idle regardless of activity |

In deployments with many OAuth users (each user gets their own session pool), lower `idle_timeout_secs` and set `max_sessions_per_auth_context` to prevent license exhaustion:

```toml
[[iris]]
name                         = "production"
server                       = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool                         = { min = 2, max = 10 }
idle_timeout_secs            = 120   # free licenses after 2 minutes idle
max_sessions_per_auth_context = 3    # each user may have at most 3 concurrent sessions
max_age_secs                 = 3600  # recycle sessions after 1 hour regardless
endpoints                    = [{ path = "/mcp/prod" }]
```

For multiple IRIS instances, each gets its own pool:

```toml
[[iris]]
name   = "primary"
server = { host = "iris1.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 5, max = 20 }
endpoints = [{ path = "/mcp/prod" }]

[[iris]]
name   = "analytics"
server = { host = "iris2.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [{ path = "/mcp/analytics" }]
```

---

## Troubleshooting

### Connection Failures

**Problem:** `Failed to connect` / `ConnectionClosed`

1. Verify the IRIS super-server is running on the configured port (default 1972)
2. Verify the MCP Server definition exists and is enabled
3. Check the Dispatch Class name is correct and the class is compiled in IRIS
4. Confirm `server.username` / `server.password` in `[[iris]]` are correct — these are gateway-level credentials (`CSPSystem` or equivalent), not IRIS application user credentials
5. Check firewall rules allow TCP to IRIS port 1972

### Connected but No Tools Appear

**Problem:** iris-mcp-server connects successfully but the LLM sees no tools (or only `iris_status`)

The server's `initialize` response already instructs the LLM: *"If IRIS tools appear to be missing or something seems wrong, call iris_status."* So the LLM should proactively call `iris_status` and surface any errors — check its output first.

If `iris_status` reports a clean connection but zero tools, the problem is on the IRIS side:

1. Verify the `SPECIFICATION` parameter on the MCP Service class is non-empty and references the correct class names
2. Confirm all listed tool/toolset classes are compiled in the correct IRIS namespace
3. Confirm the MCP Server's **Namespace** matches where the classes are compiled
4. Run iris-mcp-server with `--log-level=debug` and look for the tool count logged during discovery — if it shows 0 tools, the issue is on the IRIS side (empty `SPECIFICATION`, uncompiled classes, or wrong namespace)

### Tool Not Found

**Problem:** Tool appears in discovery but call fails, or tool not listed

1. Check the `SPECIFICATION` parameter on the MCP Service class includes the tool/toolset
2. Ensure the method is public (not marked `Private` or `Internal`)
3. Tool names are case-sensitive — check the exact names logged during discovery with `--log-level=debug`

### Authentication Failures (403)

**Problem:** `Tool call error: 403 Forbidden`

IRIS is reachable (Layer 1 OK) but the MCP endpoint is rejecting the request (Layer 2 failing):

1. Verify the endpoint entry in `[[iris]] endpoints` has the correct `username`/`password` or `bearer` for that endpoint
2. For HTTP Basic: confirm the username/password are valid IRIS credentials with access to the endpoint
3. For OAuth passthrough: confirm the MCP client is sending a valid `Authorization` header
4. Check the MCP Server's authentication settings in the Management Portal

### Secret Resolution Failures

**Problem:** Server exits at startup with a secret error

- `@{env:VAR}` — check the environment variable is set before starting the process
- `@{vault:path#field}` — verify `vault_addr` is reachable, `vault_token` is valid, the path exists, and the field name matches exactly
- Check Vault token permissions: `vault token lookup`
- Vault KV2 path format: `@{vault:iris/gateway#password}` maps to Vault path `secret/data/iris/gateway` → field `password`

### Debug Logging

Enable verbose logging to see detailed protocol activity:

```powershell
iris-mcp-server.exe --log-level=debug --log-output=stderr --config=config.toml run
```

Or via environment:

```bash
RUST_LOG=debug iris-mcp-server --config=config.toml run
```

Debug output includes:
- Connection events (connect, disconnect, reconnect)
- Tool discovery requests and ETag comparisons
- STP request/response JSON
- Smart discovery indexing

---

## Next Steps

1. **Create your IRIS backend** — See [IRIS Backend Setup](#iris-backend-setup) and [ObjectScript User Guide](ObjectScript_SDK.Guide.md)
2. **Write a config.toml** — Use the [Full TOML Reference](#full-toml-reference) as a template
3. **Test locally** — Use stdio transport with Claude Desktop
4. **Secure credentials** — Use `@{env:...}` references or configure Vault
5. **Deploy** — Docker or Kubernetes using the examples above

For more information:
- [ObjectScript User Guide](ObjectScript_SDK.Guide.md) — Creating tools and toolsets in IRIS

---

## Migrating from v0.1 Config

The configuration file format changed in v0.2. Here is a before/after for a typical simple config.

**Before:**

```toml
[server]
transport = "stdio"

[iris]
host      = "localhost"
port      = 1972
namespace = "USER"
username  = "CSPSystem"
password  = "SYS"
mcp_endpoints = ["/mcp/myapp"]
pool_size = 5

[iris.user_auth]
username = "myuser"
password = "mypass"

[logging]
level  = "info"
output = "stderr"
```

**After:**

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [
  { path = "/mcp/myapp", username = "myuser", password = "mypass" },
]

[logging]
level  = "info"
output = "stderr"
```

**What changed:**

| Old | New |
|-----|-----|
| `[server]` | `[mcp]` |
| `[iris]` (single) | `[[iris]]` (double brackets — supports multiple instances) |
| `host`, `port`, `username`, `password` at top level | Moved inside `server = { ... }` |
| `namespace` | Removed |
| `mcp_endpoints = ["/mcp/myapp"]` | `endpoints = [{ path = "/mcp/myapp" }]` |
| `pool_size = 5` | `pool = { min = 2, max = 10 }` |
| `[iris.user_auth]` section | Inline per-endpoint: `{ path = "...", username = "...", password = "..." }` |
| `"env:VAR"` secret syntax | `"@{env:VAR}"` |
