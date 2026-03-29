from mcp.server.fastmcp import FastMCP

mcp = FastMCP('addition')

@mcp.tool()
async def add(a: int, b: int) -> int:
    """Add 2 integers and return the result.
    Args:
        a: First integer to add
        b: Second integer to add"""
    return a + b


if __name__ == '__main__':
    mcp.run(transport='stdio')
