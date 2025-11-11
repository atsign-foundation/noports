from interop_spike.models import NPClientArgs, AtsignRvd
from interop_spike.wrapper import connect
from fastmcp import Client
import asyncio

def print_response(response):
    """Pretty print the tool response"""
    if response.is_error:
        print(f"❌ Error: {response.data}")
    else:
        print(f"✅ {response.data}")

def show_menu():
    """Display available commands"""
    print("\n" + "="*50)
    print("🤖 MCP Demo - Available Commands:")
    print("="*50)
    print("  greet <name>     - Get a greeting")
    print("  joke             - Hear a joke")
    print("  fun_fact         - Get a random fun fact")
    print("  roll_dice        - Roll dice (default: 1d6)")
    print("  roll_dice 20 3   - Roll 3 twenty-sided dice")
    print("  help             - Show this menu")
    print("  bye              - Exit")
    print("="*50 + "\n")
    
async def main():
    args = NPClientArgs(
        atsign="@bagel69",
        device_atsign="@chess69",
        device_name="mcp_spike",
        srvd=AtsignRvd.AMERICAS,
        local_port=9000,
        remote_port=8001
    )
    
    print("🔌 Connecting to MCP server over NoPorts...")
    await connect(args)
    await asyncio.sleep(5)
    
    async with Client("http://localhost:9000/mcp") as client:
        # Test connection
        await client.ping()
        print("✅ Connected successfully!\n")
        
        show_menu()
        
        while True:
            try:
                user_input = input("🎮 Command: ").strip()
                
                if not user_input:
                    continue
                    
                if user_input == "bye":
                    print("👋 Goodbye!")
                    break
                    
                if user_input == "help":
                    show_menu()
                    continue
                
                # Parse command and arguments
                parts = user_input.split()
                command = parts[0]
                args_dict = {}
                
                # Handle different commands
                if command == "greet":
                    if len(parts) > 1:
                        args_dict = {"name": " ".join(parts[1:])}
                    else:
                        print("❌ Usage: greet <name>")
                        continue
                        
                elif command == "roll_dice":
                    if len(parts) == 3:
                        args_dict = {"sides": int(parts[1]), "count": int(parts[2])}
                    elif len(parts) == 2:
                        args_dict = {"sides": int(parts[1])}
                    # else use defaults
                
                # Call the tool
                response = await client.call_tool(command, args_dict)
                print_response(response)
                
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"Fatal error: {e}")