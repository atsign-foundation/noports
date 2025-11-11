from interop_spike.models import NPClientArgs, AtsignRvd
from interop_spike.wrapper import connect
from fastmcp import Client
import asyncio
    
async def main():
    args = NPClientArgs(
        atsign="@bagel69",
        device_atsign="@chess69",
        device_name="mcp_spike",
        srvd=AtsignRvd.AMERICAS,
        local_port=9000,
        remote_port=8001
    )
    await connect(args)
    await asyncio.sleep(5)

    async with Client("http://localhost:9000/mcp") as client:
        await client.ping()
        response = await client.call_tool("greet", {"name": "World"})
        print(response)
        while True:
            tool_call = input("")
            if tool_call == "bye":
                break
            else:
                response = await client.call_tool(tool_call)
                print(response)
        response = await client.call_tool("ungreet", {"name": "Xavier"})
        print(response)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception:
        print()
