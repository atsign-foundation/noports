# my_dart_package/wrapper.py
import asyncio
from http.client import HTTPException
from importlib import resources
import os

import uvicorn
from fastmcp import Client, FastMCP
from fastmcp.server.http import StarletteWithLifespan
from .models import BinaryName, NPClientArgs, NPServerArgs

mcp = FastMCP()

async def connect(args: NPClientArgs) -> None:
    """Start a local NPT client process and return a FastMCP Client bound to the local port."""
    await run_async(BinaryName.NPT.value, str(args))
    
async def serve(app: StarletteWithLifespan, port: int, args: NPServerArgs):
    """Run the SSHNPD server binary and serve the FastMCP HTTP app with uvicorn.

    NOTE: uvicorn.run is blocking; this coroutine will not return until the HTTP server
    is stopped. If you need concurrent execution of the binary and HTTP server,
    refactor to start uvicorn in a background task and await both.
    """
    # Start SSHNPD first (non-blocking subprocess) then run HTTP server.
    await run_async(BinaryName.SSHNPD.value, str(args))
    config = uvicorn.Config(
        app,
        host="localhost",
        port=port,
        log_level="info",
    )
    server = uvicorn.Server(config)
    
    # Serve using the async serve method (not run())
    await server.serve()

async def run_async(executable: str, args: str) -> None:
    """Spawn an executable as an asynchronous subprocess without waiting for completion."""
    try:
        await asyncio.create_subprocess_exec(
            _resolve_executable_path(executable),
            *args.split(),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
    except asyncio.TimeoutError:
        raise HTTPException(504, "Process timed out")
    except Exception as e:
        raise HTTPException(500, f"Subprocess error: {e}")
    
    
def _resolve_executable_path(executable: str) -> str:
    """Resolve the path to the executable"""
    try:
        with resources.as_file(
            resources.files('interop_spike') / 'bin' / executable
        ) as binary_path:
            if not binary_path.exists():
                raise FileNotFoundError(f"Binary not found: {executable}")

            # Make executable on Unix systems
            if os.name != "nt":
                os.chmod(binary_path, 0o755)
            return binary_path
    except Exception:
        raise