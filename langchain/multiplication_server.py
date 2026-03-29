from mcp.server.fastmcp import FastMCP

mcp = FastMCP('multiplication')

@mcp.tool()
async def multiply(a: int, b: int) -> int:
    """Multiply 2 integers and return the result.
    Args:
        a: First integer to multiply
        b: Second integer to multiply"""
    return a * b


if __name__ == '__main__':
    mcp.run(transport='stdio')
