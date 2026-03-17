# iris-mcp-server User Guide

This guide covers how to use **iris-mcp-server** to expose IRIS tools to LLM clients via the Model Context Protocol (MCP).

For detailed information about creating tools and toolsets in ObjectScript, see the [ObjectScript USER_GUIDE](objectscript/USER_GUIDE.md).

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [IRIS Backend Setup](#iris-backend-setup)
- [Running iris-mcp-server](#running-iris-mcp-server)
- [Transport Modes](#transport-modes)
- [Security & Credentials](#security--credentials)
- [Service Discovery](#service-discovery)
- [Monitoring & Telemetry](#monitoring--telemetry)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

> **Installation:** `iris-mcp-server` is a standalone binary with no dependencies. You can find it in the kit's `bin` directory and move or copy it anywhere you need — no installation step required.

## Overview

**iris-mcp-server** is a Rust-based MCP server that bridges LLM clients (like Claude Desktop) to IRIS tools using the wgproto (Web Gateway Protocol) for communication with IRIS.

```
┌─────────────────────┐
│   Claude Desktop    │  (LLM Client)
│   or other MCP      │
│   compatible client │
└──────────┬──────────┘
           │ MCP Protocol
           │ (stdio or HTTP)
           ▼
┌─────────────────────┐
│  iris-mcp-server    │  (Rust)
│                     │
│  - MCP protocol     │
│  - Tool discovery   │
│  - Connection pool  │
│  - RAG discovery    │
└──────────┬──────────┘
           │ wgproto
           │ (Web Gateway Protocol)
           │ STP Protocol
           ▼
┌─────────────────────┐
│  %AI.MCP.Service    │  (IRIS ObjectScript)
│                     │
│  - Tool dispatch    │
│  - Policy layer     │
│  - ToolManager      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Your Tools &      │
│   ToolSets          │
└─────────────────────┘
```

**Key Transport Details**:
- iris-mcp-server communicates with IRIS using **wgproto** (Web Gateway Protocol)
- wgproto is the same low-level protocol that IIS/Apache web gateway modules use
- IRIS %CSP.WebSocket endpoints are accessed through the web gateway protocol
- This provides efficient, multiplexed connections to IRIS without requiring external web servers

## Quick Start

### 1. Create IRIS Backend

Create a simple MCP service in IRIS (see [IRIS Backend Setup](#iris-backend-setup) for details):

```objectscript
Class MyApp.MCP.SimpleService Extends %AI.MCP.Service
{
    /// List tools, toolsets, or tool refs (rust:filesystem, etc.)
    Parameter SPECIFICATION As STRING = "MyApp.Tools.Calculator";
}
```

### 2. Configure Web Application

Create a CSP web application pointing to your service class:
- Name: `/mcp/simple`
- Dispatch Class: `MyApp.MCP.SimpleService`

### 3. Run iris-mcp-server

```bash
# Install (if not already installed)
cargo install --path iris-mcp-server

# Run with stdio transport for Claude Desktop
iris-mcp-server run \
  --iris-host localhost \
  --iris-port 52773 \
  --iris-namespace USER \
  --iris-mcp-path /mcp/simple \
  --iris-username CSPSystem \
  --iris-password SYS \
  --transport stdio
```

### 4. Configure Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "iris-tools": {
      "command": "iris-mcp-server",
      "args": [
        "run",
        "--iris-host", "localhost",
        "--iris-port", "52773",
        "--iris-namespace", "USER",
        "--iris-mcp-path", "/mcp/simple",
        "--iris-username", "CSPSystem",
        "--iris-password", "SYS",
        "--transport", "stdio"
      ]
    }
  }
}
```

## Architecture

### Component Overview

- **iris-mcp-server**: MCP protocol server (Rust)
  - Implements MCP specification
  - Manages wgproto connection pooling to IRIS
  - Handles tool discovery and execution
  - Optional RAG-based smart discovery
  - Optional Remote MCP endpoints (HTTP/SSE)

- **%AI.MCP.Service**: IRIS backend (ObjectScript)
  - REST endpoints for discovery and health
  - WebSocket-style message handling via wgproto
  - Creates ToolManager for tool dispatch
  - Applies authorization and audit policies
  - Routes tool calls to appropriate providers

- **ToolManager**: IRIS tool registry (Rust + ObjectScript)
  - Unified registry for all tool sources
  - Policy enforcement layer
  - Supports ObjectScript tools, Rust tools, MCP servers

### Communication Protocol

iris-mcp-server uses **wgproto** (Web Gateway Protocol) to communicate with IRIS:

1. **wgproto** is the same low-level protocol used by IIS and Apache web gateway modules
2. It provides WebSocket-like semantics without requiring an external web server
3. Efficient multiplexing of multiple logical connections over pooled physical connections
4. Built-in support for CSP sessions, authentication, and IRIS-specific features

The **STP Protocol** (Stabilized Tool Protocol) is layered on top of wgproto for tool execution:

```
Protocol Stack:
┌─────────────────────────┐
│  MCP Protocol           │  (JSON-RPC 2.0)
├─────────────────────────┤
│  iris-mcp-server        │  (Rust - Protocol translation)
├─────────────────────────┤
│  STP Protocol           │  (JSON messages: request/response/error)
├─────────────────────────┤
│  wgproto                │  (Web Gateway Protocol)
├─────────────────────────┤
│  HTTP/TCP               │
└─────────────────────────┘
```

### Protocol Flow

```
1. Discovery:
   LLM Client → MCP list_tools → iris-mcp-server
   iris-mcp-server → (wgproto) GET /v1/services → IRIS
   IRIS → ToolManager.%Discover() → JSON tool catalog
   iris-mcp-server → MCP response → LLM Client

2. Execution:
   LLM Client → MCP call_tool → iris-mcp-server
   iris-mcp-server → (wgproto) STP request → IRIS /v1/ws
   IRIS → ToolManager.ExecuteTool() → (Auth → Execute → Audit) → result
   result → (wgproto) STP response → iris-mcp-server
   iris-mcp-server → MCP response → LLM Client
```

## Configuration

### Configuration File (TOML)

Create `config.toml`:

```toml
[iris]
host = "localhost"
port = 52773
namespace = "USER"
username = "CSPSystem"
password = "SYS"
mcp_path = "/mcp/database"

[pool]
min_connections = 5
max_connections = 20
connection_timeout = 30

[discovery]
auto_discover = true
interval_seconds = 60
cache_ttl = 300

[server]
transport = "stdio"  # or "http://0.0.0.0:8080"
log_level = "info"
```

Run with config file:

```bash
iris-mcp-server run --config config.toml
```

### Environment Variables

Override config values with environment variables:

```bash
export IRIS_HOST="localhost"
export IRIS_PORT="52773"
export IRIS_NAMESPACE="USER"
export IRIS_USERNAME="CSPSystem"
export IRIS_PASSWORD="SYS"
export IRIS_MCP_PATH="/mcp/database"
export IRIS_POOL_MIN=5
export IRIS_POOL_MAX=20

iris-mcp-server run
```

### Configuration Priority

1. Command-line arguments (highest priority)
2. Environment variables
3. Configuration file
4. Defaults (lowest priority)

## IRIS Backend Setup

### Simple Tool (extends %AI.Tool)

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

### Composite ToolSet (extends %AI.ToolSet)

Use the XML DSL to compose tools with policies:

```objectscript
Class MyApp.ToolSet.Database Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="DatabaseTools">
            <Description>SQL and database operations</Description>

            <!-- Policies -->
            <Policies>
                <Authorization Class="MyApp.Policy.ReadOnlyAuth" />
                <Audit Class="%AI.Policy.ConsoleAudit" />
            </Policies>

            <!-- Include existing tools -->
            <Include Class="%AI.Tools.SQL">
                <Requirement Name="ReadOnly" Value="1"/>
            </Include>

            <!-- Include Rust tool via ToolSet (applies policies) -->
            <Tool Name="filesystem" Class="rust:filesystem">
                <Description>File system operations</Description>
            </Tool>
        </ToolSet>
    }
}
```

### MCP Service Class

```objectscript
Class MyApp.MCP.DatabaseService Extends %AI.MCP.Service
{
    /// Can list tools, toolsets, or tool refs
    /// Best practice: Use ToolSets to apply policies
    Parameter SPECIFICATION As STRING = "MyApp.ToolSet.Database";

    /// Or mix multiple sources:
    /// Parameter SPECIFICATION As STRING = "MyApp.Tools.Calculator,MyApp.ToolSet.Database,%AI.Tools.SQL";
}
```

> **Note**: For detailed examples of creating tools and toolsets, see the [ObjectScript USER_GUIDE](objectscript/USER_GUIDE.md).

### Configure Web Application

1. Open System Management Portal
2. Navigate to: System Administration > Security > Applications > Web Applications
3. Create new application:
   - Name: `/mcp/database`
   - Namespace: USER
   - Dispatch Class: `MyApp.MCP.DatabaseService`
   - Enabled: Yes
   - CSP/ZEN: Yes
   - Authentication: Password

## Running iris-mcp-server

### Command-Line Usage

```bash
# Basic usage
iris-mcp-server run \
  --iris-host localhost \
  --iris-port 52773 \
  --iris-namespace USER \
  --iris-mcp-path /mcp/database \
  --transport stdio

# With connection pooling
iris-mcp-server run \
  --config config.toml \
  --pool-min 10 \
  --pool-max 50

# With auto-discovery
iris-mcp-server run \
  --config config.toml \
  --auto-discover \
  --discover-interval 60

# With smart discovery (RAG)
iris-mcp-server run \
  --config config.toml \
  --enable-smart-discovery \
  --embedding-model "sentence-transformers/all-MiniLM-L6-v2"
```

### Feature Flags

iris-mcp-server is built with feature flags for optional functionality:

```bash
# Build with all features
cargo build --release --all-features

# Build with specific features
cargo build --release --features "service-dynamic,smart-discovery,telemetry"

# Build minimal (static tools only)
cargo build --release --no-default-features
```

Available features:
- `service-dynamic`: Dynamic IRIS service discovery via wgproto + STP
- `smart-discovery`: RAG-based tool discovery (requires fastembed)
- `telemetry`: OpenTelemetry tracing and metrics
- `vault`: HashiCorp Vault credential management

## Transport Modes

### stdio (for Claude Desktop)

```bash
iris-mcp-server run \
  --config config.toml \
  --transport stdio
```

Claude Desktop config:
```json
{
  "mcpServers": {
    "iris": {
      "command": "iris-mcp-server",
      "args": ["run", "--config", "/path/to/config.toml", "--transport", "stdio"]
    }
  }
}
```

### HTTP (for Remote MCP)

When Remote MCP is enabled, iris-mcp-server exposes HTTP endpoints:

```bash
iris-mcp-server run \
  --config config.toml \
  --transport http://0.0.0.0:8080
```

Connect from remote client:
```bash
curl http://localhost:8080/mcp/v1/tools
```

This creates a bridge: Remote HTTP client → iris-mcp-server (HTTP) → IRIS (wgproto)

### SSE (Server-Sent Events)

For streaming responses:

```bash
iris-mcp-server run \
  --config config.toml \
  --transport sse://0.0.0.0:8080
```

## Security & Credentials

### Basic Authentication (Environment Variables)

```bash
export IRIS_USERNAME="CSPSystem"
export IRIS_PASSWORD="SYS"

iris-mcp-server run --config config.toml
```

### Configuration File

```toml
[iris]
username = "CSPSystem"
password = "SYS"
```

> **Warning**: Never commit credentials to version control!

### HashiCorp Vault Integration

Enable Vault for credential management:

```toml
[iris]
host = "localhost"
port = 52773
namespace = "USER"
mcp_path = "/mcp/database"

# Vault configuration
vault_enabled = true
vault_addr = "http://localhost:8200"
vault_token = "${VAULT_TOKEN}"
vault_secret_path = "secret/data/iris/mcp"
```

Setup Vault:

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Store IRIS credentials
vault kv put secret/iris/mcp \
  username=CSPSystem \
  password=SYS

# Get token for iris-mcp-server
export VAULT_TOKEN=$(vault token create -field=token)

# Run with Vault
iris-mcp-server run --config config.toml
```

Vault will provide:
- `username`
- `password`

### TLS/SSL Configuration

For HTTPS IRIS connections:

```toml
[iris]
host = "iris.example.com"
port = 443
use_tls = true
verify_cert = true  # Set to false for self-signed certs
```

## Service Discovery

### Manual Discovery

By default, iris-mcp-server discovers tools once at startup:

```bash
iris-mcp-server run --config config.toml
```

Discovery happens via wgproto:
1. iris-mcp-server calls `GET /v1/services` via wgproto
2. IRIS MCP Service returns tool catalog
3. iris-mcp-server caches the catalog

### Auto-Discovery

Enable periodic re-discovery to detect new tools:

```toml
[discovery]
auto_discover = true
interval_seconds = 60  # Re-discover every 60 seconds
cache_ttl = 300        # Cache results for 5 minutes
```

This is useful when:
- Tools are added/removed dynamically
- Multiple services share the same MCP server
- Development environments with frequent changes

### Smart Discovery (RAG)

Enable RAG-based semantic tool discovery:

```bash
# Build with smart-discovery feature
cargo build --release --features smart-discovery

# Run with smart discovery
iris-mcp-server run \
  --config config.toml \
  --enable-smart-discovery \
  --embedding-model "sentence-transformers/all-MiniLM-L6-v2"
```

Configuration:

```toml
[discovery]
smart_discovery = true
embedding_model = "sentence-transformers/all-MiniLM-L6-v2"
embedding_cache_size = 10000
similarity_threshold = 0.7
```

Smart discovery uses semantic search to find relevant tools based on natural language queries instead of exact name matching.

## Monitoring & Telemetry

### Logging

Configure log level:

```bash
export RUST_LOG=info  # debug, info, warn, error
iris-mcp-server run --config config.toml
```

Or in config file:

```toml
[server]
log_level = "info"
```

### OpenTelemetry (with telemetry feature)

Enable distributed tracing:

```toml
[telemetry]
enabled = true
service_name = "iris-mcp-server"
jaeger_endpoint = "http://localhost:14268/api/traces"
```

Run Jaeger for trace visualization:

```bash
# Start Jaeger all-in-one
docker run -d --name jaeger \
  -p 16686:16686 \
  -p 14268:14268 \
  jaegertracing/all-in-one:latest

# View traces at http://localhost:16686
```

### Prometheus Metrics

Export metrics for Prometheus scraping:

```toml
[telemetry]
metrics_enabled = true
metrics_port = 9090
```

Prometheus config:

```yaml
scrape_configs:
  - job_name: 'iris-mcp-server'
    static_configs:
      - targets: ['localhost:9090']
```

Available metrics:
- `iris_mcp_tool_calls_total` - Total tool executions
- `iris_mcp_tool_duration_seconds` - Tool execution latency
- `iris_mcp_connection_pool_active` - Active wgproto connections
- `iris_mcp_discovery_cache_hits` - Discovery cache hit rate

### Health Checks

Check IRIS backend health via wgproto:

```bash
# iris-mcp-server queries this endpoint via wgproto
# You can test it directly via HTTP to IRIS:
curl http://localhost:52773/mcp/database/v1/health

# Example response:
{
  "status": "healthy",
  "timestamp": "2026-02-23T10:30:00.000Z",
  "server": "IRIS MCP Gateway",
  "service": "MyApp.MCP.DatabaseService",
  "specification": "MyApp.ToolSet.Database",
  "version": "2.0.0",
  "toolcount": 15
}
```

## Production Deployment

### Docker

Create `Dockerfile`:

```dockerfile
FROM rust:1.75 as builder
WORKDIR /build
COPY . .
RUN cargo build --release --features service-dynamic,telemetry

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/target/release/iris-mcp-server /usr/local/bin/
COPY config.toml /etc/iris-mcp/config.toml

ENTRYPOINT ["iris-mcp-server"]
CMD ["run", "--config", "/etc/iris-mcp/config.toml"]
```

Build and run:

```bash
docker build -t iris-mcp-server:latest .

docker run -d \
  --name iris-mcp \
  -e VAULT_TOKEN=${VAULT_TOKEN} \
  -p 8080:8080 \
  iris-mcp-server:latest
```

### Kubernetes

Create deployment:

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
        ports:
        - containerPort: 8080
        env:
        - name: VAULT_TOKEN
          valueFrom:
            secretKeyRef:
              name: vault-token
              key: token
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
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

### Helm Chart

Install with Helm:

```bash
helm install iris-mcp ./helm/iris-mcp-server \
  --set iris.host=iris.example.com \
  --set iris.namespace=PRODUCTION \
  --set vault.enabled=true \
  --set vault.addr=http://vault.example.com:8200
```

### Connection Pooling Best Practices

Configure pool sizes based on workload:

```toml
[pool]
# Development
min_connections = 2
max_connections = 10

# Production (light load)
min_connections = 5
max_connections = 20

# Production (heavy load)
min_connections = 10
max_connections = 50

# Connection timeout in seconds
connection_timeout = 30
```

Guidelines:
- **min_connections**: Always-open wgproto connections for low latency
- **max_connections**: Scale up under load, but avoid overwhelming IRIS
- **Rule of thumb**: 1 connection per ~10 concurrent users

## Troubleshooting

### Connection Issues

**Problem**: `Failed to connect to IRIS via wgproto`

**Solutions**:
1. Verify IRIS web application exists and is enabled
2. Check web application Dispatch Class is correct
3. Verify IRIS CSP server is running
4. Check firewall allows HTTP connections to IRIS
5. Check IRIS logs: `^DMC` global for debug info

```objectscript
// View IRIS logs
USER> zwrite ^DMC

// Clear logs
USER> kill ^DMC
```

### Tool Not Found

**Problem**: `Tool 'ExecuteQuery' not found`

**Solutions**:
1. Check SPECIFICATION parameter includes the tool/toolset
2. Verify tool class exists and is compiled
3. Ensure tool method is public (not Private/Internal)
4. Check tool name matches exactly (case-sensitive)
5. Test discovery manually via HTTP to IRIS:

```bash
curl http://localhost:52773/mcp/database/v1/services
```

### Authentication Failures

**Problem**: `401 Unauthorized`

**Solutions**:
1. Verify username/password are correct
2. Check web application authentication settings
3. Ensure user has appropriate roles/permissions
4. For Vault: verify `VAULT_TOKEN` is set and valid

### Performance Issues

**Problem**: Slow tool execution

**Solutions**:
1. Increase connection pool size:
   ```toml
   [pool]
   max_connections = 50
   ```

2. Enable discovery caching:
   ```toml
   [discovery]
   cache_ttl = 600
   ```

3. Monitor connection pool metrics:
   ```bash
   curl http://localhost:9090/metrics | grep pool
   ```

4. Check IRIS system performance (CPU, memory, locks)

### Debug Mode

Enable verbose logging:

```bash
export RUST_LOG=debug
export IRIS_DEBUG=1

iris-mcp-server run --config config.toml
```

This will show:
- Detailed wgproto protocol messages
- Tool discovery results
- Connection pool activity
- Policy enforcement decisions

### Testing IRIS Endpoints

Test IRIS MCP Service endpoints directly via HTTP:

```bash
# Health check
curl http://localhost:52773/mcp/database/v1/health

# List services (tool discovery)
curl http://localhost:52773/mcp/database/v1/services
```

> **Note**: These are REST endpoints. The STP protocol endpoint (`/v1/ws`) is accessed by iris-mcp-server using wgproto, not directly accessible via standard HTTP tools.

## Advanced Topics

### Multiple IRIS Instances

Connect to multiple IRIS services:

```toml
[[services]]
name = "production-db"
host = "iris-prod.example.com"
port = 52773
namespace = "PRODUCTION"
mcp_path = "/mcp/database"

[[services]]
name = "analytics"
host = "iris-analytics.example.com"
port = 52773
namespace = "ANALYTICS"
mcp_path = "/mcp/analytics"
```

Each service gets its own wgproto connection pool.

### Custom Policy Enforcement

IRIS policies are enforced server-side through the ToolManager. See [ObjectScript USER_GUIDE](objectscript/USER_GUIDE.md) for details on:
- Authorization policies
- Audit policies
- Discovery policies

### Load Balancing

For high availability, deploy multiple iris-mcp-server instances behind a load balancer:

```
┌──────────────┐
│ Load Balancer│
└──────┬───────┘
       │
       ├─────► iris-mcp-server (instance 1) ──(wgproto)──► IRIS
       ├─────► iris-mcp-server (instance 2) ──(wgproto)──► IRIS
       └─────► iris-mcp-server (instance 3) ──(wgproto)──► IRIS
```

Each instance maintains its own wgproto connection pool to IRIS.

### Understanding wgproto

**wgproto** (Web Gateway Protocol) is the low-level protocol used by:
- InterSystems Web Gateway (IIS/Apache modules)
- iris-mcp-server (direct implementation)

Benefits:
- **No external web server needed**: iris-mcp-server communicates directly with IRIS
- **Efficient multiplexing**: Multiple logical requests over pooled connections
- **Native IRIS support**: CSP sessions, authentication, WebSocket semantics
- **High performance**: Binary protocol optimized for IRIS communication

## Next Steps

1. **Create your IRIS backend** - See [IRIS Backend Setup](#iris-backend-setup)
2. **Configure iris-mcp-server** - Create a config.toml file
3. **Test locally** - Use stdio transport with Claude Desktop
4. **Add security** - Integrate Vault for credential management
5. **Monitor** - Enable telemetry and metrics
6. **Deploy** - Use Docker/Kubernetes for production

For more information:
- [ObjectScript USER_GUIDE](objectscript/USER_GUIDE.md) - Creating tools and toolsets
- [IRIS MCP README](../iris-llm/cls/AI/MCP/README.md) - Technical details of IRIS backend
- [STP Protocol](../iris-llm/STP.md) - WebSocket protocol specification
- [wgproto](../wgproto/README.md) - Web Gateway Protocol implementation
