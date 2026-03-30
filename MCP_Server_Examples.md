# Sample MCP Services

The `objectscript/cls/Sample/MCP/` directory contains sample MCP Service classes for testing and demonstrating iris-mcp-server integration with IRIS.

## MCP Services

### Sample.MCP.Service.Calculator

**Purpose**: Sample/demo MCP service with policies

**Tools exposed**:
- `Sample.AI.ToolSet.BasicMath` - Math tools with audit policy

**Use case**: Demonstrates best practices for production MCP services with policy enforcement

## Setup in IRIS

### 1. Load the Classes

```objectscript
USER> Do $system.OBJ.ImportDir("/path/to/examples/objectscript/cls", "*.cls", "ck", .errors, 1)
```

### 2. Create MCP Server for Calculator Service

1. Open System Management Portal
2. Navigate to: **System Administration > Security > Applications > MCP Servers**
3. Click **"Create New MCP Server"**
4. Configure:
   - **Name**: `/mcp/calculator`
   - **Namespace**: `USER` (or your namespace)
   - **Dispatch Class**: `Sample.MCP.Service.Calculator`
   - **Enabled**: Yes
   - **Authentication**: Password (or Unauthenticated for dev)
5. Save

Alternatively, you can create the MCP Server programmatically:

```ObjectScript
zn "%SYS"

set props("NameSpace")="USER"
set props("AutheEnabled")=64
set props("Enabled")=1
set props("DispatchClass")="Sample.MCP.Service.Calculator"
set props("Type")=18

do ##class(Security.Applications).Create("/mcp/calculator", .props)
``` 

## Configuring iris-mcp-server

### Authentication Overview

iris-mcp-server has two independent authentication layers:

| Layer | What it secures | Where configured |
|-------|-----------------|-----------------|
| **wgproto transport** | iris-mcp-server to IRIS web gateway | `[[iris]] server.username` / `server.password` |
| **CSP application** | Per-request user identity for each endpoint | `[[iris]] endpoints[].username` / `password` / `bearer` |

The transport credential (`CSPSystem`) opens the connection. If the CSP web application requires authentication, the endpoint credential supplies the user identity for each request.

### Basic Configuration (Unauthenticated endpoint)

If the web application is configured with **Authentication: None** (typical for dev), only the transport credential is needed:

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

If the web application requires authentication (Password or Delegated), add credentials to the endpoint entry:

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [
  { path = "/mcp/calculator", username = "_SYSTEM", password = "SYS" },
]

[logging]
level  = "debug"
output = "file"
file   = "iris-mcp.log"
```

For a Bearer token instead of HTTP Basic:

```toml
endpoints = [
  { path = "/mcp/calculator", bearer = "mytoken" },
]
```

For Remote MCP (HTTP/SSE) with OAuth, the `Authorization` header from each incoming MCP client session is forwarded to IRIS automatically — no endpoint credentials needed.

## Run iris-mcp-server

Use the following command to run iris-mcp-server with a configuration file.

```bash
iris-mcp-server --config test-config.toml run
```

You can also supply most configuration elements through the command line:

```bash
iris-mcp-server --transport stdio run \ 
    --iris-host localhost \ 
    --iris-port 11401 \ 
    --iris-user _SYSTEM \ 
    --iris-password SYS \ 
    --iris-endpoint /mcp/calculator
```

### Test with Python MCP Client

Tools are namespaced by endpoint path: `/mcp/calculator` → prefix `mcp_calculator`.

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test_iris_mcp():
    server_params = StdioServerParameters(
        command="iris-mcp-server",
        args=["--config", "test-config.toml", "run"],
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List tools
            tools = await session.list_tools()
            print(f"Available tools: {[t.name for t in tools.tools]}")

            # Test Add (note the mcp_calculcator prefix)
            result = await session.call_tool("mcp_calculator_Add", {"a": 5, "b": 3})
            print(f"Add(5, 3) = {result}")

asyncio.run(test_iris_mcp())
```

## Tool Reference

### Math Tools (Sample.AI.Tools.Math)

#### Add(a, b)
Adds two numbers.

**Parameters**:
- `a` (Numeric): First number
- `b` (Numeric): Second number

**Returns**:
```json
{
  "operation": "add",
  "a": 5,
  "b": 3,
  "result": 8
}
```

#### Subtract(a, b)
Subtracts b from a.

#### Multiply(a, b)
Multiplies two numbers.

#### Divide(a, b)
Divides a by b. Returns an error object if b is zero.

**Error example**:
```json
{
  "error": "Division by zero",
  "code": "DIVIDE_BY_ZERO"
}
```

### Test Utilities (Sample.AI.Tools.TestUtilities)

#### Echo(text)
Returns the input text with length and timestamp metadata.

#### GetTestData()
Returns structured data with various JSON types for serialization testing.

#### Fail(message)
Always throws with the specified message. Tests error propagation.

**Parameters**:
- `message` (String): Error message (default: "Intentional test failure")

#### Slow(milliseconds)
Sleeps for the specified duration then returns timing info. Tests timeout handling.

**Parameters**:
- `milliseconds` (Integer): Sleep duration (default: 1000)

#### GetTimestamp()
Returns the current timestamp in HOROLOG, ISO 8601, and Unix formats.

#### ValidateParams(required, optional)
Echoes back parameters to test required vs optional argument handling.

## Automated Testing

See the Python test suite in `iris-mcp/tests/` for automated integration tests using these services.
