from interop_spike.wrapper import serve
from interop_spike.models import NPServerArgs
from fastmcp import FastMCP
import asyncio

mcp = FastMCP("My MCP Server")


@mcp.tool
def greet(name: str) -> str:
    return f"Hello, {name}!"
    
async def main():
    # Provide all required NPServerArgs fields, including policy.
    args = NPServerArgs(
        atsign="@chess69",
        manager_atsign="@bagel69",
        device_name="mcp_spike",
    )
    app = mcp.http_app()
    # serve() blocks; no server handle is returned.
    await serve(app, 8000, args)
    # If you need post-server logic, refactor serve() to run uvicorn in a background task.

if __name__ == "__main__":
    asyncio.run(main())
