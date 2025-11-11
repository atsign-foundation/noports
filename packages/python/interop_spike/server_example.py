from interop_spike.wrapper import serve
from interop_spike.models import NPServerArgs
from fastmcp import FastMCP
import asyncio
import random

mcp = FastMCP("MCP")


@mcp.tool
def greet(name: str) -> str:
    return f"Hello, {name}!"

@mcp.tool
def joke() -> str:
    return "Why don't scientists trust atoms? Because they make up everything!"

@mcp.tool()
def fun_fact() -> str:
    """Get a random fun fact."""
    facts = [
        "Honey never spoils. Archaeologists have found 3,000-year-old honey in Egyptian tombs that's still edible!",
        "A group of flamingos is called a 'flamboyance'.",
        "Bananas are berries, but strawberries aren't!",
        "The shortest war in history lasted only 38-45 minutes (Anglo-Zanzibar War, 1896).",
        "Octopuses have three hearts and blue blood.",
        "A day on Venus is longer than its year.",
        "Wombat poop is cube-shaped!",
        "There are more possible iterations of a game of chess than atoms in the observable universe.",
        "Scotland's national animal is the unicorn.",
        "The voice of Mickey Mouse and the voice of Minnie Mouse got married in real life!"
    ]
    return f"💡 Fun Fact: {random.choice(facts)}"

@mcp.tool()
def roll_dice(sides: int = 6, count: int = 1) -> str:
    """
    Roll one or more dice.
    
    Args:
        sides: Number of sides on each die (default: 6)
        count: Number of dice to roll (default: 1)
    """
    if count < 1 or count > 10:
        return "Error: Can only roll between 1 and 10 dice at a time"
    if sides < 2 or sides > 100:
        return "Error: Dice must have between 2 and 100 sides"
    
    rolls = [random.randint(1, sides) for _ in range(count)]
    total = sum(rolls)
    
    if count == 1:
        return f"🎲 Rolled a d{sides}: **{rolls[0]}**"
    else:
        return f"🎲 Rolled {count}d{sides}: {rolls}\nTotal: **{total}**"

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
