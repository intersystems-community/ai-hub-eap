# Sample MCP Services

This directory contains sample MCP Service classes demonstrating `iris-mcp-server` integration with InterSystems IRIS.

## MCP Services

### `Sample.MCP.Service.Calculator`

**Purpose**: Sample MCP service demonstrating policies and tool composition.

**Tools exposed**:
- `Sample.AI.ToolSet.BasicMath` — Add, Subtract, Multiply, Divide with an audit policy

**Use case**: Shows best practices for a production MCP service: ToolSet composition, audit policy enforcement, and endpoint setup.

## Setup in InterSystems IRIS

1. Load the sample classes:
   ```objectscript
   USER> Do $system.OBJ.ImportDir("/path/to/examples/objectscript/cls", "*.cls", "ck", .errors, 1)
   ```
2. In the Management Portal go to **System Administration > Security > Applications > MCP Servers**.
3. Click **Create New MCP Server** and specify:
   - Name: `/mcp/calculator`
   - Namespace: `USER` (or your namespace)
   - Dispatch Class: `Sample.MCP.Service.Calculator`
   - Enabled: ✓ Yes
   - Authentication: **Password** (or **Unauthenticated** for development)
4. Click **Save**.

## Using with `iris-mcp-server`

### Authentication Overview

iris-mcp-server has two independent authentication layers:

| Layer | What it secures | Where configured |
|-------|-----------------|-----------------|
| **wgproto transport** | iris-mcp-server to IRIS web gateway | `[[iris]] server.username` / `server.password` |
| **CSP application** | Per-request user identity | `[[iris]] endpoints[].username` / `password` / `bearer` |

### Basic Configuration (Unauthenticated endpoint)

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [
  { path = "/mcp/calculator" },
]

[logging]
level  = "debug"
output = "file"
file   = "iris-mcp.log"
```

### Configuration with Authenticated Endpoint

```toml
[[iris]]
name   = "local"
server = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
endpoints = [
  { path = "/mcp/calculator", username = "_SYSTEM", password = "SYS" },
]
```

For a Bearer token: `{ path = "/mcp/calculator", bearer = "mytoken" }`.

For Remote MCP (HTTP/SSE) with OAuth the `Authorization` header from each incoming client session is forwarded to IRIS automatically — no endpoint credentials needed.

### Run and Test

```bash
iris-mcp-server --config config.toml run
```

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test():
    params = StdioServerParameters(command="iris-mcp-server", args=["--config", "config.toml", "run"])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print([t.name for t in tools.tools])
            result = await session.call_tool("mcp_calculator_Add", {"a": 5, "b": 3})
            print(result)

asyncio.run(test())
```

## Automated Testing

See the Python test suite in `iris-mcp/tests/` for automated integration tests.
