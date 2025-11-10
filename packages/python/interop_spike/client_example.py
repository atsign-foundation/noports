from .models import NPClientArgs, AtsignRvd
from .wrapper import connect
import asyncio


    
async def main():
    args = NPClientArgs(
        atsign="@bagel69",
        device_atsign="@chess69",
        device_name="mcp_spike",
        srvd=AtsignRvd.AMERICAS,
        local_port=9000,
        remote_host="localhost",
        remote_port=8000
    )

    async with connect(args) as client:
        await client.ping()
        response = await client.call_tool("greet", {"name": "World"})
        print(response)

if __name__ == "__main__":
    asyncio.run(main())
