# `iris-mcp-server` User Guide

This guide covers how to install, configure, and run `iris-mcp-server` to expose IRIS tools to LLM clients via the Model Context Protocol (MCP).

For detailed information about creating tools and toolsets in ObjectScript, see the [ObjectScript SDK User Guide](objectscript/USER_GUIDE.md).

> [!NOTE]
> Some of the advanced features explained in this guide, including but not limited to Vault integration, multi-server setup and the container version of this tool are experimental and may change significantly between builds, or may not be part of the build you downloaded.

## Table of Contents

- [`iris-mcp-server` User Guide](#iris-mcp-server-user-guide)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Overview](#overview)
  - [Quick Start](#quick-start)
  - [Architecture](#architecture)
    - [Protocol Stack](#protocol-stack)
    - [Protocol Flow](#protocol-flow)
  - [Configuring `iris-mcp-server`](#configuring-iris-mcp-server)
    - [Configuration File Reference](#configuration-file-reference)
    - [Secret and Credentials](#secret-and-credentials)
    - [CLI Flags](#cli-flags)
  - [Transport Modes](#transport-modes)
    - [stdio (Claude Desktop)](#stdio-claude-desktop)
    - [HTTP (Remote MCP)](#http-remote-mcp)
    - [HTTPS (Remote MCP with TLS)](#https-remote-mcp-with-tls)
    - [Local Auto-Discovery](#local-auto-discovery)
  - [Security \& Credentials](#security--credentials)
    - [Layer 1 - Authenticating `iris-mcp-server` to InterSystems IRIS](#layer-1---authenticating-iris-mcp-server-to-intersystems-iris)
    - [Layer 2 - MCP Endpoint Credentials](#layer-2---mcp-endpoint-credentials)
    - [Host Header Validation](#host-header-validation-multi-container-and-reverse-proxy-deployments)
    - [Remote MCP — OAuth Passthrough](#remote-mcp--oauth-passthrough)
    - [OAuth 2.1 Authorization Server Proxy](#oauth-21-authorization-server-proxy)
      - [Configuration](#configuration)
      - [How It Works](#how-it-works)
      - [Token Types](#token-types)
      - [IRIS Issuer URL Requirement](#iris-issuer-url-requirement)
    - [Enterprise-Managed Authorization (EMA)](#enterprise-managed-authorization-ema)
    - [HashiCorp Vault Integration](#hashicorp-vault-integration)
    - [Using TLS](#using-tls)
      - [`wgproto` TLS](#wgproto-tls)
      - [Server-Side TLS (Remote MCP Endpoint)](#server-side-tls-remote-mcp-endpoint)
  - [InterSystems IRIS Backend Setup](#intersystems-iris-backend-setup)
    - [Simple Tool](#simple-tool)
    - [ToolSet with Policies](#toolset-with-policies)
    - [MCP Service Class](#mcp-service-class)
  - [Service Discovery](#service-discovery)
    - [How Discovery Works](#how-discovery-works)
    - [Tool Refresh](#tool-refresh)
    - [Endpoint Auto-Discovery](#endpoint-auto-discovery)
    - [Tool Namespacing](#tool-namespacing)
    - [Reconnection](#reconnection)
  - [The `iris_status` Diagnostic Tool](#the-iris_status-diagnostic-tool)
  - [Smart Discovery (RAG)](#smart-discovery-rag)
  - [Monitoring \& Telemetry](#monitoring--telemetry)
    - [Real-Time Monitor](#real-time-monitor)
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
    - [Authentication Failures (401/403)](#authentication-failures-401403)
    - [Secret and Credential Resolution Failures](#secret-and-credential-resolution-failures)
    - [Debug Logging](#debug-logging)
  - [Next Steps](#next-steps)
  - [Migrating from `iris-mcp-server` Version 1](#migrating-from-iris-mcp-server-version-1)

## Installation 

`iris-mcp-server` is a standalone binary included in the `bin` directory of your IRIS installation. No installation step is required — copy or reference it directly.

> **Upgrading from v0.1?** The configuration file format changed in v2 (as of build ~140). See [Migrating from v0.1 Config](#migrating-from-iris-mcp-server-version-1) at the end of this guide.


## Overview

`iris-mcp-server` is a Rust-based MCP gateway that bridges LLM clients (Claude Desktop, remote MCP clients) to IRIS MCP Server endpoints, handling tool discovery and execution transparently.

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
           │ InterSystems IRIS Web Gateway Protocol
           ▼
┌─────────────────────┐
│  %AI.MCP.Service    │  (InterSystems IRIS ObjectScript)
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

`iris-mcp-server` uses the native Web Gateway Transport Protocol (wgproto) to communicate to InterSystems IRIS; no external web server is required.

---

## Quick Start

1. Create an MCP service in InterSystems IRIS (see [InterSystems IRIS Backend Setup](#intersystems-iris-backend-setup) for details):

  ```objectscript
  Class MyApp.MCP.SimpleService Extends %AI.MCP.Service
  {
      Parameter SPECIFICATION As STRING = "MyApp.Tools.Calculator";
  }
  ```

2. Create an MCP server that points to your service class. To do this, open the InterSystems IRIS Management Portal and go to **System Administration > Security > Applications > MCP Servers** and click on **Create New MCP Server**.

    For example, you can create an MCP server called `/mcp/simple` that points to the `MyApp.MCP.SimpleService` dispatch class:
      - **Name**: `/mcp/simple`
      - **Dispatch Class**: `MyApp.MCP.SimpleService`
      - **Authentication**: **Password** (or **Unauthenticated** for development; **OAuth 2.0** for Remote MCP with Bearer tokens)

3. Run `iris-mcp-server` with your configuration file:
    ```bash
    iris-mcp-server.exe --config=config.toml run
    ```

    Example minimal `config.toml`:
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

4. Configure Claude Desktop to point to `iris-mcp-server` by adding the following to your `%APPDATA%\Claude\claude_desktop_config.json`:
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

5. Restart Claude Desktop. A gear icon appears when MCP servers are active. Claude logs are in `%APPDATA%\Claude\logs`.

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
iris-mcp-server  →  wgproto GET /v1/services  →  InterSystems IRIS
InterSystems IRIS  →  ToolManager.%Discover()  →  JSON tool catalog
iris-mcp-server  →  MCP response         →  LLM Client
```

**Tool execution:**
```
LLM Client  →  MCP call_tool                    →  iris-mcp-server
iris-mcp-server  →  wgproto+ws /v1/ws           →  InterSystems IRIS
InterSystems IRIS  →  ToolManager.ExecuteTool()  →  (Auth → Execute → Audit)  →  result
result  →  STP response                          →  iris-mcp-server
iris-mcp-server  →  MCP response                →  LLM Client
```

---

## Configuring `iris-mcp-server`

The behavior and features of `iris-mcp-server` are determined by a combination of CLI flags, a `.toml` configuration file, and its default settings. When the same value is specified in multiple locations, the highest priority (shown below) source applies:

```
CLI flags  >  TOML config file  >  built-in defaults
```

[Credentials](#secrets-and-credentials) in the `.toml` file are not overridden by environment variables directly. Instead, use `@{env:VAR}` references inside the `.toml` file to read the environment variables during startup.

### Configuration File Reference

```toml
# ── MCP Transport ─────────────────────────────────────────────────────────────
[mcp]
transport  = "stdio"        # stdio | http | https
host       = "127.0.0.1"     # bind address for HTTP/HTTPS transports (default: 127.0.0.1)
port       = 8080           # bind port
base_route = "/mcp"         # HTTP route prefix (default: /mcp)

# Allowed Host header values for inbound HTTP/HTTPS requests (optional).
# Localhost variants are always permitted. Default behaviour:
#   loopback bind (127.0.0.1): only localhost variants accepted.
#   public bind  (0.0.0.0):    all Host values accepted (a warning is logged).
# Set to enforce a strict allowlist on a public server:
# allowed_hosts = ["mcp.example.com", "mcp.example.com:8080"]

# TLS for the MCP HTTP transport (required when transport = "https")
# [mcp.tls]
# cert = "/etc/certs/server.crt"             # path to PEM certificate
# key  = "/etc/certs/server.key"             # path to PEM private key
# Secret references are also accepted:
# cert = "@{vault:tls/iris-mcp#certificate}"
# key  = "@{vault:tls/iris-mcp#private_key}"

# ── IRIS Servers ──────────────────────────────────────────────────────────────
# Use [[iris]] (double brackets) — one entry per InterSystems IRIS instance.
# Multiple instances can be declared in the same file.

[[iris]]
name = "production"

# wgproto super-server connection credentials.
# Credential fields accept a literal value, @{env:VAR}, or @{vault:path#field}.
server = { host = "iris.example.com", port = 1972, username = "@{env:WG_USER}", password = "@{env:WG_PASS}" }

# WebSocket session pool for this instance.
pool = { min = 2, max = 10 }

# MCP Server paths (endpoints) on this InterSystems IRIS instance.
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

# How often to retry a lost connection (default: "30s"). Accepts "30s", "1m", "500ms" etc.
reconnect_interval = "30s"

# How often to re-fetch the tool list (default: "5m").
tool_refresh_interval = "5m"

# Maximum bytes to accumulate from InterSystems IRIS for a single tool response (default: 10 MiB).
# Increase for tools that return very large payloads; decrease if your LLM has a
# small context window and is being overwhelmed by large results.
max_response_bytes = 10485760

# Maximum time to wait for a WebSocket session to open (default: "30s").
connect_timeout = "30s"

# How long a pooled WebSocket session may sit idle before it is closed (default: "5m").
# Closing an idle session causes the InterSystems IRIS job to Halt, freeing its license slot.
# Lower values free licenses faster; higher values reduce reconnection overhead.
idle_timeout = "5m"

# Maximum number of concurrent pooled sessions per (endpoint, auth_context) pair.
# Each OAuth user or opaque token gets its own pool up to this limit.
# Prevents runaway license consumption when many distinct identities are active.
# Default: same as pool.max.
max_sessions_per_auth_context = 10

# Hard cap on total session lifetime, regardless of activity.
# When set, a session older than this is dropped the next time it becomes idle
# (InterSystems IRIS job Halts, license freed). Off by default — only idle_timeout applies.
# Useful in high-churn environments to guarantee periodic license recycling.
# max_age = "1h"   

# TLS for the wgproto connection to this instance (optional).
# Presence of the tls field enables TLS; absence means plaintext.
# tls = {}                                         # system CA roots
# tls = { ca_cert = "/etc/certs/iris-ca.crt" }    # custom CA
# tls = { ca_cert = "/etc/certs/iris-ca.crt",      # mutual TLS
#          cert    = "/etc/certs/client.crt",
#          key     = "/etc/certs/client.key" }

# ── OAuth 2.1 Authorization Server Proxy ─────────────────────────────────────
# Optional. When present, iris-mcp-server serves:
#   GET /.well-known/oauth-authorization-server  (RFC 8414 — AS metadata discovery)
#   GET /.well-known/oauth-protected-resource    (RFC 9728 — resource metadata, MCP 2025-11-25)
# and proxies OAuth flows (authorize, token, JWKS, register) to IRIS via wgproto.
# [oauth]
# iris                 = "production"                    # [[iris]] section that is the AS
# host                 = "https://mcp.example.com"       # public base URL (optional)
# well_known_path      = "/.well-known/oauth-authorization-server"  # override if non-standard
# allowed_paths        = ["/csp/sys/auth"]               # extra paths to proxy (e.g. login pages)
# metadata_cache_ttl   = "5m"                            # how long to cache AS metadata

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

### Secret and Credentials

Credential fields (`username`, `password`, `bearer`, `cert`, `key`, etc.) accept one of three formats:

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
| `--transport=<spec>` | `stdio`, `http://host:port`, `https://host:port` |
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
| `--iris-endpoint=<path>` | MCP Server path — may be repeated for multiple endpoints |
| `--auto-discover-interval=<secs>` | Poll for local IRIS instances every N seconds (0 = disabled) |
| `--status-tool=<bool>` | Expose `iris_status` diagnostic tool (default: `true`) |


`monitor` subcommand flags (one of `--pid` or `--socket` is required):

| Flag | Description |
|------|-------------|
| `--pid=<pid>` | Connect to the `iris-mcp-server` process with this PID |
| `--socket=<path>` | Connect to the IPC socket at this explicit path |

## Transport Modes

The following sections demonstrate how to set the transport mode for `iris-mcp-server`.

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

> When using `stdio` transport, set `output = "file"` so logs do not mix with the MCP protocol stream on `stderr`.

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

### Local Auto-Discovery

When `--auto-discover-interval` is set, `iris-mcp-server` polls for local running InterSystems IRIS instances (via `iris qlist` on Linux/Mac, or the Windows Registry) and automatically connects to any that appear:

```powershell
iris-mcp-server.exe --transport=http://0.0.0.0:8080 --config=config.toml run --auto-discover-interval=60
```

---

## Security & Credentials

`iris-mcp-server` has two independent authentication layers that serve different purposes:

| Layer | What it secures | Configuration location |
|-------|-----------------|-----------------|
| **IRIS server auth** | iris-mcp-server connecting to the IRIS server | `[[iris]] server.username` / `server.password` |
| **MCP endpoint auth** | Per-request identity presented to each IRIS MCP Server | `[[iris]] endpoints[].username/password/bearer` |

Understanding both layers is essential; authenticating the connection to InterSystems IRIS does **not** automatically authenticate individual requests to the MCP endpoint inside it.

### Layer 1 - Authenticating `iris-mcp-server` to InterSystems IRIS

The `[iris]` fields `username` and `password` authenticate `iris-mcp-server` to your InterSystems IRIS instance. These credentials must be those of a privileged gateway user such as `CSPSystem` (the same credential that IIS/Apache web gateway modules use).

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

> Never commit credentials to version control. Use `@{env:...}` references or [HashiCorp Vault integration](#hashicorp-vault-integration).

### Layer 2 - MCP Endpoint Credentials

Each request targets an MCP Server in InterSystems IRIS. These MCP servers map a URL path to a `%AI.MCP.Service` subclass. If that endpoint requires authentication, InterSystems IRIS returns **403 Forbidden** unless credentials accompany each request.

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

For Remote MCP (HTTP transport), the `Authorization` header from the incoming MCP client session is automatically forwarded to IRIS per-request and takes priority over any configured endpoint credentials. See [OAuth Passthrough](#remote-mcp-oauth-passthrough).

Different authentication modes are used for different scenarios. The following table details these scenarios and their configurations:

| Scenario | Configuration |
|----------|---------------|
| Remote MCP + OAuth Bearer tokens | Omit endpoint auth, the header is forwarded automatically |
| stdio transport (HTTP Basic) | `{ path = "...", username = "...", password = "..." }` |
| stdio transport (API key) | `{ path = "...", bearer = "..." }` |
| Unauthenticated endpoint | `{ path = "..." }` (s)et endpoint to *Unauthenticated* in InterSystems IRIS) |

> **Security:** Unauthenticated endpoints expose tools to anyone who can reach the IRIS server. Only use `Unauthenticated` for local development; all production environments should require authentication.

### Host Header Validation (Multi-Container and Reverse-Proxy Deployments)

When using HTTP or HTTPS transport, `iris-mcp-server` validates the `Host` header on incoming requests to prevent DNS rebinding attacks. The default behaviour depends on the bind address:

| Bind address | Default behaviour |
|---|---|
| `127.0.0.1` / `::1` | Only `localhost` variants accepted |
| `0.0.0.0` (public) | All `Host` values accepted |

When binding to `0.0.0.0`, all `Host` values are accepted by default. This is the correct behaviour for Docker, Kubernetes, and reverse-proxy deployments where the client connects using a service hostname (e.g. `mcpserver:8080`) — authentication is the primary protection in these environments and no extra configuration is required.

For defence-in-depth, you can harden the server by specifying an explicit allowlist. When `allowed_hosts` is set, only those hostnames (plus `localhost` variants, which are always included) are accepted:

```toml
[mcp]
transport     = "http"
host          = "0.0.0.0"
port          = 8080
allowed_hosts = ["mcp.example.com", "mcp.example.com:8080"]
```

### Remote MCP — OAuth Passthrough

When `iris-mcp-server` runs in HTTP/HTTPS mode, each MCP session from a remote client carries its own `Authorization` header (commonly an OAuth 2.0 Bearer token). `iris-mcp-server` forwards the header value unchanged to IRIS on every request within that session. Any valid scheme (Bearer, API-key-as-Authorization, etc.) works without server-side changes.

OAuth passthrough is always active for the HTTP/HTTPS transport. Endpoint `username`/`password`/`bearer` configuration acts as a fallback only when no `Authorization` header arrives from the client.

For IRIS to validate incoming Bearer tokens automatically, OAuth authentication must be enabled on the MCP Server endpoint in the IRIS Management Portal. When enabled, IRIS validates the token at WebSocket session open time — by the time a tool call runs, the end-user identity is already established. Use `OnPreServer()` in your `%AI.MCP.Service` subclass to perform claim-based authorization (scope, audience, groups) after authentication has already succeeded.

Requests carrying a Bearer token whose `exp` claim is already in the past are rejected by `iris-mcp-server` before reaching IRIS.

### OAuth 2.1 Authorization Server Proxy

In addition to forwarding tokens that clients already hold (passthrough), `iris-mcp-server` can act as a **transparent broker** for IRIS acting as an OAuth 2.1 Authorization Server. When enabled, `iris-mcp-server`:

- Serves the RFC 9728 Protected Resource Metadata endpoint (`GET /.well-known/oauth-protected-resource`) — required by the MCP spec 2025-11-25 — so clients can discover the AS from a 401 or proactively
- Serves the RFC 8414 AS metadata discovery endpoint (`GET /.well-known/oauth-authorization-server`) so MCP clients can auto-discover the full AS configuration
- Rewrites endpoint URLs in the metadata response to point at `iris-mcp-server`'s own public address, keeping the IRIS backend private
- Proxies all OAuth flows — Authorization Code + PKCE, Client Credentials, JWKS, Dynamic Client Registration — through to IRIS via wgproto

IRIS must be configured as an OAuth 2.1 Authorization Server (RFC 8414, RFC 7591) for this to work. Refer to the InterSystems IRIS OAuth documentation for the IRIS-side setup.

#### Configuration

Add an `[oauth]` section to your configuration file:

```toml
[oauth]
iris = "production"          # name of the [[iris]] section whose IRIS instance is the AS

# Optional: public base URL for URL rewriting in the AS metadata response.
# If omitted, derived from the incoming Host header.
# Set explicitly when running behind a reverse proxy that does not forward Host accurately.
host = "https://mcp.example.com"

# Optional: path to fetch AS metadata from IRIS via wgproto.
# Defaults to /.well-known/oauth-authorization-server (RFC 8414 standard).
# Override when the AS metadata is served at a non-standard path.
# well_known_path = "/custom/as-metadata"

# Optional: additional URL prefixes to allow through the proxy beyond those
# listed in the AS metadata. Use for IRIS login pages served outside the
# standard OAuth prefix when supporting the Authorization Code flow interactively.
# allowed_paths = ["/csp/sys/auth"]
```

The `iris` field must match the `name` of one of your `[[iris]]` sections. That IRIS instance acts as the AS for the entire `iris-mcp-server` deployment — all MCP endpoints share the same Authorization Server.

#### How It Works

1. A MCP client fetches `GET /.well-known/oauth-protected-resource` from `iris-mcp-server` (RFC 9728). The response identifies iris-mcp-server as the Protected Resource and names the Authorization Server at the same public base URL. Clients following the 2025-11-25 spec use this endpoint first; older clients may skip straight to step 2.
2. The client fetches `GET /.well-known/oauth-authorization-server` from `iris-mcp-server` (RFC 8414). `iris-mcp-server` retrieves this from IRIS via wgproto, rewrites all endpoint URLs to point at `iris-mcp-server`'s own address (replacing the IRIS-internal host), and returns the rewritten document. The `issuer` field is **not** rewritten — IRIS must be configured with its own public issuer URL for token `iss` claims to match.
3. The client uses the discovered endpoints to obtain a token (Authorization Code + PKCE or Client Credentials). All requests hit `iris-mcp-server`, which proxies them to IRIS.
4. The client then uses the Bearer token for MCP calls. `iris-mcp-server` forwards the token to IRIS per the existing OAuth passthrough mechanism.

If a client skips discovery and sends a request without a valid token, iris-mcp-server returns a `401 Unauthorized` with a `WWW-Authenticate` header that includes a `resource_metadata` URL (pointing at `/.well-known/oauth-protected-resource`), allowing the client to bootstrap AS discovery from the 401 challenge alone.

Only paths explicitly listed in the AS metadata (plus any `allowed_paths`) are forwarded to IRIS. All other requests through the proxy return 404, limiting the blast radius of path-probing attacks.

#### Token Types

Both **JWT** and **opaque** Bearer tokens are supported for MCP calls:

| Token type | iris-mcp-server pool routing | Pre-expiry check | IRIS validation |
|---|---|---|---|
| JWT | By `sub`+`aud` claims — survives token rotation | Yes — expired tokens rejected before touching IRIS | Local JWKS verification, fast |
| Opaque | By raw token value — each rotation creates a new pool entry | No | Introspection endpoint call per request or session |

JWT tokens issued by IRIS's OAuth AS are recommended for production: iris-mcp-server can detect expired tokens early, and IRIS validates signatures locally from cached JWKS without an introspection round-trip.

#### IRIS Issuer URL Requirement

IRIS must be configured with its **public issuer URL** (the value of `host`, or the URL MCP clients use to reach `iris-mcp-server`). The `issuer` field in the AS metadata must match the `iss` claim in tokens IRIS issues — `iris-mcp-server` rewrites endpoint URLs but cannot rewrite `iss` claims in already-issued tokens. A mismatch causes clients that validate `iss` to reject otherwise valid tokens.

### Enterprise-Managed Authorization (EMA)

The MCP specification (stable extension, June 2025) defines [Enterprise-Managed Authorization](https://github.com/modelcontextprotocol/ext-auth/blob/main/specification/stable/enterprise-managed-authorization.mdx) — a mechanism for organizations to centrally provision MCP server access via their corporate Identity Provider (Okta, Microsoft Entra, etc.). Instead of each user manually authorizing each MCP server, access is inherited automatically from existing SSO groups and roles.

EMA uses the **Identity Assertion JWT Authorization Grant (ID-JAG)**: the MCP client obtains an assertion JWT from the enterprise IdP during SSO login, then exchanges it for an access token from the MCP server's Authorization Server — without redirecting the user through a consent screen.

#### What iris-mcp-server does

`iris-mcp-server` participates in the EMA flow as the **Protected Resource** (the MCP server). It already serves the RFC 9728 Protected Resource Metadata endpoint that MCP clients use to discover the Authorization Server. **No additional configuration to iris-mcp-server is required for EMA** — the integration point is the Authorization Server, which sits between the IdP and iris-mcp-server.

#### Configuration options

There are two deployment patterns:

**Path A — IRIS as the Authorization Server**

IRIS acts as the OAuth 2.1 AS. The enterprise IdP (Okta, Entra) is configured as an upstream OpenID Connect provider that IRIS trusts. Claude exchanges the ID-JAG with IRIS's AS, which validates it against the IdP and issues an IRIS-scoped access token. iris-mcp-server proxies the AS flows as normal using the existing `[oauth]` configuration.

```toml
[oauth]
iris = "production"                    # IRIS instance that acts as the AS
host = "https://mcp.example.com"       # public URL for URL rewriting
```

IRIS-side setup required:
- Configure IRIS as an OAuth 2.1 Authorization Server via **Management Portal → System → Security → OAuth 2.0**
- Register the enterprise IdP (Okta, Entra) as an OpenID Connect server in the IRIS OAuth configuration
- Refer to the [InterSystems IRIS OAuth 2.0 & OpenID Connect documentation](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH) for full setup instructions

**Path B — External Authorization Server (Okta / Entra as the AS)**

The enterprise IdP acts directly as the AS. In this path, no `[oauth]` section is configured in iris-mcp-server — the server simply passes Bearer tokens through to IRIS unchanged (the existing OAuth passthrough mechanism). IRIS is configured to validate JWTs issued by the external AS directly.

iris-mcp-server configuration: no `[oauth]` section needed. Tokens flow through to IRIS transparently.

IRIS-side setup required:
- Configure IRIS as an OAuth 2.0 **resource server** that trusts the external AS — provide the IdP's JWKS URI in the IRIS OAuth resource server settings so IRIS can validate incoming JWTs locally
- The MCP endpoint's `AutheEnabled` must include OAuth 2.0 Bearer token validation
- Refer to the [InterSystems IRIS OAuth 2.0 & OpenID Connect documentation](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH) for the IRIS-side setup

> **Note:** In this path, iris-mcp-server does not serve the RFC 9728 Protected Resource Metadata endpoint, so MCP clients cannot auto-discover the AS from iris-mcp-server. The client must be pre-configured with the AS URL, or the enterprise IdP must handle discovery through other means (e.g. organisation-level MCP client configuration in Claude's enterprise settings).

#### EMA from the client side

EMA is implemented on the MCP client (Claude, Claude Code). Once your AS is correctly advertised via RFC 9728, EMA-capable clients automatically use the ID-JAG flow when the enterprise IdP is configured — no per-user setup is required. See the [MCP EMA specification](https://github.com/modelcontextprotocol/ext-auth) for the full client-side flow.

### HashiCorp Vault Integration

You can integrate `iris-mcp-server` with HashiCorp Vault by adding references to your vault in the `[secrets]` section of your configuration file.

All secret references are resolved once at startup before any connections are established. If any secret fails to resolve, the server exits with an error.

The following example configures `iris-mcp-server` to use secrets from a local vault:

1. Configure the `[secrets]` section of your configuration file:

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
    > **Kubernetes:** use `vault_token_file` with a [projected service account token](https://developer.hashicorp.com/vault/docs/auth/kubernetes) volume rather than storing a static token in a Secret. Mount the projected token at a path like `/var/run/secrets/vault/token` and set `vault_token_file` to that path. The token is automatically rotated by Kubernetes and re-read by `iris-mcp-server` on the next startup.

2. Reference Vault secrets in credential fields using `@{vault:path#field}` where `path` is relative to `vault_mount`.

    For example, with `vault_mount = "secret"`, the reference `@{vault:iris/gateway#password}` reads the field `password` from the Vault KV2 secret at `secret/data/iris/gateway`.

    ```toml
    [[iris]]
    name   = "production"
    server = { host = "iris.example.com", port = 52773,
              username = "@{vault:iris/gateway#username}",
              password = "@{vault:iris/gateway#password}" }
    pool   = { min = 10, max = 50 }
    endpoints = [
      { path = "/mcp/prod", bearer = "@{vault:iris/prod#app_token}" },
    ]
    ```

3. Set up the Vault secrets. 

   ```bash
   # Enable KV v2 secrets engine (if not already enabled)
   vault secrets enable -path=secret kv-v2

   # Store InterSystems IRIS gateway credentials
   vault kv put secret/iris/gateway \
     username=CSPSystem \
     password=SYS

   # Store InterSystems IRIS application token
   vault kv put secret/iris/prod \
     app_token=eyJ...
   ```
4. Run with the token in the environment:

    ```bash
    export VAULT_TOKEN="s.xxxx"
    iris-mcp-server --config=config.toml run
    ```

### Using TLS

`iris-mcp-server` is associated with two connections:
- `wgproto`: `iris-mcp-server` → InterSystems IRIS
- Server-side: LLM clients → `iris-mcp-server`

The sections below detail how to encrypt each connection.

#### `wgproto` TLS

You can encrypt the `wgproto` connection between `iris-mcp-server` and InterSystems IRIS by adding the `tls` field to the `[[iris]]` entry of your configuration file.

The presence of the `tls` field enables TLS, and its value determines which certificates and keys to use for the connection:
- `tls = {}` - Use the system's default CA certificates.
- `tls = { ca_cert = path/to/ca.crt }` - Use the CA certificate `ca.crt` to verify the identity of the InterSystems IRIS server.
- `tls = { ca_cert = "path/to/ca.crt", cert = "path/to/client.crt", key = "/path/to/client.key" }` - (Mutual TLS only) Use the CA certificate `ca.crt` to verify the identity of the InterSystems IRIS server and present the certificate `client.crt` to identify the client to the server.
  
`iris-mcp-server` uses the system CA certificates unless overridden. The InterSystems IRIS gateway must also be [configured for TLS](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSA_config_tls).

The following examples demonstrate how to use the `tls` field:

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

If you've integrated `iris-mcp-server` with [HashiCorp Vault](#hashicorp-vault-integration), you can reference your secrets instead:

```toml
tls = { ca_cert = "@{vault:tls/iris#ca_cert}" }
```

#### Server-Side TLS (Remote MCP Endpoint)

You can encrypt the connection between LLM clients and `iris-mcp-server` (that is, the MCP HTTP transport endpoint) by adding the `cert` and `key` to `[mcp.tls]`:

```toml
# Both from files
[mcp.tls]
cert = "/etc/certs/server.crt"
key  = "/etc/certs/server.key"
```

If you've integrated `iris-mcp-server` with [HashiCorp Vault](#hashicorp-vault-integration), you can reference your secrets instead:

```
# HashiCorp Vault integration
[mcp.tls]
cert = "@{vault:tls/iris-mcp#certificate}"
key  = "@{vault:tls/iris-mcp#private_key}"
```


## InterSystems IRIS Backend Setup

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

This example composes tools with policies using XML DSL. Notice that it extends `%AI.ToolSet`:

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

MCP service classes can reference tools, toolsets, or tool references:

```objectscript
Class MyApp.MCP.DatabaseService Extends %AI.MCP.Service
{
    /// SPECIFICATION lists tools, toolsets, or tool refs (comma-separated)
    Parameter SPECIFICATION As STRING = "MyApp.ToolSet.Database";
}
```

You can then add an MCP server to InterSystem IRIS that uses your service class:

1. Open IRIS Management Portal
2. Navigate to: **System Administration → Security → Applications → MCP Servers**
3. Create a new application:
   - **Name:** `/mcp/database`
   - **Namespace:** USER
   - **Dispatch Class:** `MyApp.MCP.DatabaseService` (this is your `%AI.MCP.Service` subclass)
   - **Enabled:** Yes
   - **Authentication:** Password (or Unauthenticated for dev/internal use; **OAuth 2.0** for Remote MCP with Bearer tokens)

---

## Service Discovery

### How Discovery Works

Tool discovery is deferred until the first MCP client connects. At that point `iris-mcp-server` fetches the tool list from each configured endpoint:

1. Sends `GET {endpoint}/v1/services` to IRIS (conditional GET with `If-None-Match` ETag)
2. InterSystems IRIS MCP Service returns a JSON tool catalog
3. `iris-mcp-server` registers the tools, computing a per-tool SHA-256 hash
4. A service-level ETag is stored for future conditional GETs

If discovery fails (for example, because IRIS is temporarily unreachable), the existing registration is retained so already-registered tools remain available. A fresh discovery attempt is made on the next tool call.

### Tool Refresh

The background tool-refresh loop re-fetches tool lists every `tool_refresh_interval` (default: `"5m"`). A 304 Not Modified response means no change and nothing is re-registered. On a 200 response, per-tool hashes are compared; only changed tools trigger an MCP `tools/list_changed` notification to connected clients.

```toml
name                  = "dev"
server                = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool                  = { min = 2, max = 5 }
tool_refresh_interval = "1m"     # more frequent polling during development
endpoints             = [{ path = "/mcp/myapp" }]
```

### Endpoint Auto-Discovery

If `endpoints` is omitted from `[[iris]]`, `iris-mcp-server` queries the InterSystems IRIS CSP application registry for all apps matching `/mcp*` and connects to each one automatically.

```toml
[[iris]]
name   = "local"
server = { host = "localhost", port = 1972, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 5 }
# endpoints omitted -> auto-discover /mcp* apps
```

### Tool Namespacing

When multiple MCP Servers are connected, tools from each service are prefixed with a service ID derived from the MCP Server's path. This prevents name collisions and tells the LLM which service a tool belongs to.

The service ID is the endpoint path of the MCP Server with the leading slash stripped and remaining slashes replaced with underscores:

| MCP Server name | Service ID prefix | Example tool name |
|---------------|-------------------|-------------------|
| `/mcp` | `mcp` | `mcp_ExecuteQuery` |
| `/mcp/database` | `mcp_database` | `mcp_database_ExecuteQuery` |
| `/mcp/myapp` | `mcp_myapp` | `mcp_myapp_GetCustomer` |

When there is only one endpoint, tools still carry the prefix. Keep this in mind when writing system prompts or instructions that refer to tools by name.

### Reconnection

If the connection to InterSystems IRIS is lost, `iris-mcp-server` automatically attempts to reconnect in the background using the interval configured by `reconnect_interval` (default: `"30s"`). You do not need to restart `iris-mcp-server`.

The example below configures `iris-mcp-server` to attempt to reconnect every 10 seconds:

```toml
name               = "dev"
server             = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool               = { min = 2, max = 5 }
reconnect_interval = "10s"     # retry faster during development
endpoints          = [{ path = "/mcp/myapp" }]
```

---

## The `iris_status` Diagnostic Tool

When `iris-mcp-server` encounters connection errors or startup failures, it exposes a special MCP tool called `iris_status` that the LLM can call to report the problem. This tool only appears in the tool list when there are active errors.

When the LLM sees `iris_status`, it means something went wrong. Calling it returns a structured report of all current errors:

```
iris_status result:
- mcp_database: connection failed — refused at localhost:1972
- mcp_analytics: authentication error — 403 Forbidden (check endpoint credentials)
```

This allows the LLM to proactively report issues rather than silently failing when tools are called.

`iris_status` should only be used in development; in a production environment, you should disable this tool with the `--status-tool=false` flag to ensure internal state is hidden from the LLM:

```powershell
iris-mcp-server.exe --config=config.toml run --status-tool=false
```

---

## Smart Discovery (RAG)

Smart discovery uses a local embedding model (fastembed / `AllMiniLML6V2`) to perform semantic search across all registered tool descriptions. When an LLM asks for tools matching a natural-language query, relevant tools are ranked by cosine similarity rather than exact name matching.

> The embedding model (~25 MB) is downloaded from HuggingFace on first use.

To enable this feature in your configuration file:

```toml
[features]
smart_discovery = true
```

Smart discovery is indexed automatically as tools are registered. No additional CLI flags are required.

---

## Monitoring & Telemetry


### Real-Time Monitor

`iris-mcp-server` includes a live terminal dashboard that shows connection pool status, active sessions, tool call throughput, and a live log feed — all updated every 500 ms without interrupting the running server.

**Starting the monitor:**

The server prints its IPC socket path at startup:

```
INFO IPC server listening on \\.\pipe\iris-mcp-1234 (local-only, owner DACL)
```

Connect to it by PID or by the socket path:

```powershell
# Windows — connect by PID
iris-mcp-server.exe monitor --pid 1234

# Windows — connect by explicit socket path
iris-mcp-server.exe monitor --socket \\.\pipe\iris-mcp-1234
```

```bash
# Unix — connect by PID
iris-mcp-server monitor --pid 1234

# Unix — connect by explicit socket path
iris-mcp-server monitor --socket /run/user/1000/iris-mcp-1234.sock
```

Press `q` or `Ctrl-C` to exit. The `iris-mcp-server` process continues running normally.

**Dashboard panels:**

| Panel | Content |
|-------|---------|
| **GATEWAY** | Active MCP sessions (HTTP and stdio), authenticated contexts (distinct OAuth identities), WebSocket sessions, error counts, and discovery cache hit rates |
| **CONNECTIONS** | Per-endpoint WebSocket pool state (active, queued, idle, total), P50/P99 latency per tool, session eviction counts by reason, IRIS connection failure breakdown by reason, HTTP pool self-heal counters (stale/healed/failed), and WS session error breakdown (send, receive, stale-session) |
| **TOOLS** | Per-tool call counts, success/error rates, P50/P99 execution latency, and input/output byte totals |
| **LOG** | Live stream of recent INFO/WARN/ERROR log lines, color-coded by severity |

**Monitor security:**

The monitor communicates with the server through a local IPC channel — a named pipe on Windows and a Unix domain socket on Unix. The channel is strictly one-way: the monitor receives periodic read-only metrics snapshots and cannot send commands to the server.

*Windows:* The named pipe is not accessible over the network. On the local machine, access is restricted to the user who started `iris-mcp-server`, the SYSTEM account, and members of the local Administrators group. No other local user account can connect to the monitor.

*Unix:* The socket file is created with mode `0600`. Only the user who started `iris-mcp-server` and root can connect to the monitor. Unix domain sockets are not accessible over the network.

In both cases the process ID is embedded in the socket path, preventing collisions when multiple `iris-mcp-server` instances run on the same host.


### Logging

`iris-mcp-server` has robust logging capabilities. It collects and outputs the following information:
- Connection events (connect, disconnect, reconnect)
- Tool discovery requests and ETag comparisons
- STP request/response JSON
- Smart discovery indexing

Logging has several levels. These are ordered by least to most severe:
1. `debug` (least severe, most verbose)
2. `info`
3. `warn`
4. `error` (most severe, least verbose)

The log level expresses the minimum severity you want to know about. This means that if you set the log level to `info`, the log will contain messages of severity `info` and above, which includes `warn` and `error`.

To set the log level with flags (overrides the configuration file):

```powershell
iris-mcp-server.exe --log-level=debug --log-output=stderr --config=config.toml run
```

To set the log level in [`config.toml`](#configuration-file-reference):
```toml
[logging]
level  = "debug"     # error | warn | info | debug | trace
output = "file"
file   = "C:\\logs\\iris-mcp.log"
```

For file output, `file` is required. For stderr output, `file` is ignored.

You can also set `RUST_LOG=debug` (or any `env_logger`-compatible filter) to override the log level from the environment:

```bash
RUST_LOG=debug iris-mcp-server --config=config.toml run
```

### OpenTelemetry Tracing

To enable OpenTelemetry Tracing:

1. Enable the `telemetry` feature in the `config.toml`:

```toml
[features]
telemetry = true
```

2. Set the OTLP endpoint via the standard environment variable. Traces are exported via OTLP (gRPC):

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
```

3. Run `Jaeger` for local trace visualization:

```bash
docker run -d --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  jaegertracing/all-in-one:latest
# View traces at http://localhost:16686
```

### Verifying Tool Discovery

The easiest way to confirm whether `iris-mcp-server` is discovering tools is to check the logs at startup:

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

To deploy `iris-mcp-server` on Kubernetes, create a Deployment:

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

Each InterSystems IRIS instance has its own WebSocket session pool, the size of which is determined by `pool = { min, max }`. Each pool slot is one WebSocket connection to InterSystems IRIS (one concurrent tool call in flight per slot).

The following example shows how to use the `pool` field:

```toml
[[iris]]
name      = "production"
server    = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool      = { min = 5, max = 20 }    # up to 20 concurrent tool calls
endpoints = [{ path = "/mcp/prod" }]
```

As a general rule, `max` should be at least as large as the number of tool calls you expect to run simultaneously. `min` sets the number of sessions kept warm at idle.

**Session lifetime tuning**: Each pooled session corresponds to one InterSystems IRIS license slot (job). Three settings control how long sessions live:

| Setting | Default | Effect |
|---------|---------|--------|
| `connect_timeout_secs` | `"30s"` | Maximum time to wait for a WebSocket session to open |
| `idle_timeout` | `"5m"` | Close sessions idle longer than this (InterSystems IRIS job halts and its license is freed) |
| `max_sessions_per_auth_context` | `pool.max` | Cap on concurrent sessions per OAuth user / token identity |
| `max_age` | off | Hard cap on total session lifetime; session dropped on next idle regardless of activity |

All duration fields accept humantime strings: `"30s"`, `"2m"`, `"1h"`, `"500ms"`, etc.

**OAuth deployments:** IRIS validates a Bearer token once, at WebSocket session open. It does not re-validate the token while the session is running — a session stays alive even after the token expires. `idle_timeout` is therefore the primary mechanism for ensuring stale-token sessions are cleaned up. Set it to no more than your OAuth token lifetime so that expired sessions are recycled before the next token rotation.

In deployments with many OAuth users (each user gets their own session pool), lower `idle_timeout` and set `max_sessions_per_auth_context` to prevent license exhaustion:

```toml
[[iris]]
name                         = "production"
server                       = { host = "iris.example.com", port = 1972, username = "CSPSystem", password = "SYS" }
pool                         = { min = 2, max = 10 }
idle_timeout                 = "2m"   # free licenses after 2 minutes idle
max_sessions_per_auth_context = 3     # each user may have at most 3 concurrent sessions
max_age                      = "1h"   # recycle sessions after 1 hour regardless
endpoints                    = [{ path = "/mcp/prod" }]
```

For multiple InterSystems IRIS instances, each gets its own pool:

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

This section covers common errors and how to diagnose/resolve them. For more general information about logging and monitoring, see [Monitoring & Telemetry](#monitoring--telemetry).

### Connection Failures

**Problem:** `Failed to connect` / `ConnectionClosed`

1. Verify the InterSystems IRIS superserver is running on the configured port.
2. Verify that the MCP server in InterSystems IRIS (**System Administration > Security > Applications > MCP Servers**) exists and is enabled.
3. Check the Dispatch Class name is correct and the class is compiled in InterSystems IRIS.
4. Confirm `server.username` / `server.password` in `[[iris]]` are correct — these are gateway-level credentials (`CSPSystem` or equivalent), not IRIS application user credentials.
5. Check firewall rules allow TCP to the InterSystems IRIS superserver port.

### Connected but No Tools Appear

**Problem:** `iris-mcp-server` connects successfully but the LLM cannot see your tools (or the LLM only sees `iris_status`)

The server's `initialize` response already instructs the LLM: *"If InterSystems IRIS tools appear to be missing or something seems wrong, call `iris_status`,"* so you should check the output of that first.

If `iris_status` reports a clean connection but zero tools, the problem is on the InterSystems IRIS side:

1. Verify that the `SPECIFICATION` parameter on the MCP Service class is non-empty and references the correct class names.
2. Confirm all listed tool/toolset classes are compiled in the correct IRIS namespace.
3. Confirm the that the MCP server's **Namespace** matches where the classes are compiled.
4. Run `iris-mcp-server` with `--log-level=debug` and look for the tool count logged during discovery — if it shows 0 tools, the issue is on the IRIS side (empty `SPECIFICATION`, uncompiled classes, or wrong namespace).

### Tool Not Found

**Problem:** Tool appears in discovery but call fails, or tool not listed

1. Check the `SPECIFICATION` parameter on the MCP Service class includes the tool/toolset.
2. Ensure the method is public (not marked `Private` or `Internal`).
3. Tool names are case-sensitive — check the exact names logged during discovery with `--log-level=debug`.

### Authentication Failures (401/403)

**Problem:** `Tool call error: 401 Unauthorized` or `403 Forbidden`

This error means that InterSystems IRIS is reachable ([Layer 1](#layer-1---authenticating-iris-mcp-server-to-intersystems-iris)) but the MCP endpoint is rejecting the request ([Layer 2](#layer-2---mcp-endpoint-credentials)).

When authentication is required but credentials are missing or invalid, `%AI.MCP.Service` returns a JSON `401 Unauthorized` response. If the `[oauth]` proxy is enabled, `iris-mcp-server` additionally includes a `WWW-Authenticate` header pointing at `/.well-known/oauth-protected-resource`, allowing MCP clients to bootstrap AS discovery from the 401 challenge.

1. Verify the endpoint entry in `[[iris]] endpoints` has the correct `username`/`password` or `bearer` for that endpoint.
2. For HTTP Basic: confirm the username/password are valid IRIS credentials with access to the endpoint.
3. For OAuth passthrough: confirm the MCP client is sending a valid `Authorization` header.
4. Verify the MCP server's authentication settings in the Management Portal.

**Recommended authentication settings** for MCP web applications in the Management Portal:

| Use case | `AutheEnabled` setting |
|---|---|
| Development / trusted network | **Unauthenticated** |
| Password / API key | **Password** (and supply credentials in `[[iris]] endpoints`) |
| OAuth 2.0 Bearer tokens | **OAuth 2.0** (tokens forwarded by `iris-mcp-server` from MCP clients) |

### Secret and Credential Resolution Failures

**Problem:** Server exits at startup with a secret error

1. `@{env:VAR}` - Verify the environment variable is set before starting the process.
2. `@{vault:path#field}` - Verify `vault_addr` is reachable, `vault_token` is valid, the path exists, and the field name matches exactly.
3. Verify Vault token permissions: `vault token lookup`.
4. Vault KV2 path format: `@{vault:iris/gateway#password}` maps to Vault path `secret/data/iris/gateway` → field `password`.

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

1. **Create your IRIS backend** — See [IRIS Backend Setup](#intersystems-iris-backend-setup) and [ObjectScript User Guide](ObjectScript_SDK_Guide.md)
2. **Write a config.toml** — Use the [Full TOML Reference](#configuration-file-reference) as a template
3. **Test locally** — Use stdio transport with Claude Desktop
4. **Secure credentials** — Use `@{env:...}` references or configure Vault
5. **Deploy** — Docker or Kubernetes using the examples above

For more information:
- [ObjectScript User Guide](ObjectScript_SDK.Guide.md) — Creating tools and toolsets in IRIS

---

## Migrating from `iris-mcp-server` Version 1

The configuration file format changed between `iris-mcp-server` version 1 and 2. These changes are as follows:

| Old | New |
|-----|-----|
| `[server]` | `[mcp]` |
| `[iris]` (single) | `[[iris]]` (Supports multiple instances) |
| `host`, `port`, `username`, `password` at top level | Moved inside `server = { ... }` |
| `namespace` | Removed |
| `mcp_endpoints = ["/mcp/myapp"]` | `endpoints = [{ path = "/mcp/myapp" }]` |
| `pool_size = 5` | `pool = { min = 2, max = 10 }` |
| `[iris.user_auth]` section | Inline per-endpoint: `{ path = "...", username = "...", password = "..." }` |
| `"env:VAR"` secret syntax | `"@{env:VAR}"` |

Below are a set of sample configuration files which demonstrate these changes and should help you migrate to version 2.

Sample version 1 configuration file:

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

Sample version 2 configuration file:

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
