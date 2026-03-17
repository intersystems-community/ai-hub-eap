# Sample MCP Services

This directory contains sample MCP Service classes for testing and demonstrating iris-mcp-server integration with IRIS.

## MCP Services

### Sample.MCP.Service.Testing

**Purpose**: Automated testing of iris-mcp-server

**Tools exposed**:
- `Sample.AI.Tools.Math` - Add, Subtract, Multiply, Divide
- `Sample.AI.Tools.TestUtilities` - Echo, GetTestData, Fail, Slow, GetTimestamp, ValidateParams

**Use case**: Comprehensive automated test suite for iris-mcp-server

### Sample.MCP.Service.Calculator

**Purpose**: Sample/demo MCP service with policies

**Tools exposed**:
- `Sample.AI.ToolSet.BasicMath` - Math tools with audit policy

**Use case**: Demonstrates best practices for production MCP services with policy enforcement

## Setup in IRIS

### 1. Load the Classes

```objectscript
// In IRIS Terminal
USER> Do $system.OBJ.ImportDir("/path/to/examples/objectscript/cls", "*.cls", "ck", .errors, 1)
```

### 2. Create Web Application for Testing Service

1. Open System Management Portal
2. Navigate to: **System Administration > Security > Applications > Web Applications**
3. Click **"Create New Web Application"**
4. Configure:
   - **Name**: `/mcp/testing`
   - **Namespace**: `USER` (or your namespace)
   - **Dispatch Class**: `Sample.MCP.Service.Testing`
   - **Enabled**: ✓ Yes
   - **CSP/ZEN**: ✓ Yes
   - **Authentication**: Password (or Delegated)
5. Save

### 3. Create Web Application for Calculator Service (Optional)

Repeat the above steps with:
- **Name**: `/mcp/calculator`
- **Dispatch Class**: `Sample.MCP.Service.Calculator`

### 4. Verify Setup

Test the REST endpoints:

```bash
# Health check
curl http://localhost:52773/mcp/testing/v1/health

# List available tools
curl http://localhost:52773/mcp/testing/v1/services
```

Expected response from `/v1/services` should include tools like:
- `Add`
- `Multiply`
- `Echo`
- `GetTestData`
- `Fail`
- `Slow`

## Using with iris-mcp-server

### Basic Configuration

Create `test-config.toml`:

```toml
[iris]
host = "localhost"
port = 52773
namespace = "USER"
username = "CSPSystem"
password = "SYS"
mcp_path = "/mcp/testing"

[pool]
min_connections = 2
max_connections = 10

[server]
transport = "stdio"
log_level = "debug"
```

### Run iris-mcp-server

```bash
iris-mcp-server run --config test-config.toml
```

### Test with Python MCP Client

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test_iris_mcp():
    server_params = StdioServerParameters(
        command="iris-mcp-server",
        args=["run", "--config", "test-config.toml"],
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List tools
            tools = await session.list_tools()
            print(f"Available tools: {[t.name for t in tools.tools]}")

            # Test Add
            result = await session.call_tool("Add", {"a": 5, "b": 3})
            print(f"Add(5, 3) = {result}")

            # Test Echo
            result = await session.call_tool("Echo", {"text": "Hello, MCP!"})
            print(f"Echo result: {result}")

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
Divides a by b. Returns error if b is zero.

**Error example**:
```json
{
  "error": "Division by zero",
  "code": "DIVIDE_BY_ZERO"
}
```

### Test Utilities (Sample.AI.Tools.TestUtilities)

#### Echo(text)
Returns the input text unchanged with metadata.

**Returns**:
```json
{
  "input": "Hello",
  "length": 5,
  "timestamp": "2026-02-23T10:30:00.000Z"
}
```

#### GetTestData()
Returns structured data with various types for serialization testing.

**Returns**:
```json
{
  "string": "Hello, World!",
  "integer": 42,
  "float": 3.14159,
  "boolean": true,
  "null": null,
  "array": [1, 2, 3, 4, 5],
  "nested": {"key1": "value1", "key2": "value2"}
}
```

#### Fail(message)
Always fails with the specified error message. Tests error handling.

**Parameters**:
- `message` (String): Error message (default: "Intentional test failure")

#### Slow(milliseconds)
Sleeps for specified milliseconds then returns. Tests timeout handling.

**Parameters**:
- `milliseconds` (Integer): Sleep duration (default: 1000)

**Returns**:
```json
{
  "requested_ms": 1000,
  "actual_ms": 1001,
  "timestamp": "2026-02-23T10:30:00.000Z"
}
```

#### GetTimestamp()
Returns current timestamp in various formats.

**Returns**:
```json
{
  "horolog": "66477,38400",
  "iso8601": "2026-02-23T10:30:00.000Z",
  "unix_timestamp": "1708685400"
}
```

#### ValidateParams(required, optional)
Tests parameter validation and optional parameters.

**Parameters**:
- `required` (String): Required parameter
- `optional` (String): Optional parameter

## Automated Testing

See the Python test suite in `iris-mcp-server/tests/` for automated integration tests using these services.
