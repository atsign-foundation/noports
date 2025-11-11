from interop_spike.wrapper import serve
from interop_spike.models import NPServerArgs
from fastmcp import FastMCP
import asyncio

mcp = FastMCP("MCP")


@mcp.tool
def greet(name: str) -> str:
    return f"Hello, {name}!"
    
@mcp.tool
def ungreet(name: str) -> str:
    return f"Bye bye, {name}"

@mcp.tool
def joke() -> str:
    return "Why don't scientists trust atoms? Because they make up everything!"

async def main():
    args = NPServerArgs(
        atsign="@chess69",
        manager_atsign="@bagel69",
        device_name="mcp_spike",
        permit_open="localhost:8001"
    )
    app = mcp.http_app()
    await serve(app, 8001, args)

if __name__ == "__main__":
    asyncio.run(main())
