#!/usr/bin/env python3

import subprocess
from typing import Any, List, Optional

from pydantic import BaseModel
import uvicorn
from fastapi import FastAPI, status
from fastapi_versioning import VersionedFastAPI, version
from fastapi.staticfiles import StaticFiles
from loguru import logger

app = FastAPI(
    title="nb-vpn API",
    description="nb-vpn is a BlueOS extension providing NetBird (WireGuard mesh VPN) connectivity",
)
logger.info("Starting nb-vpn manager!")


class ConnectRequest(BaseModel):
    setup_key: str
    management_url: Optional[str] = None


def _redact(args: List[str]) -> List[str]:
    """Hide the setup key in logs."""
    out = list(args)
    for i, a in enumerate(out):
        if a == "--setup-key" and i + 1 < len(out):
            out[i + 1] = "***"
    return out


def run(args: List[str]) -> str:
    logger.debug(f"Running: {' '.join(_redact(args))}")
    proc = subprocess.run(
        args,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return proc.stdout


@app.post("/connect", status_code=status.HTTP_200_OK)
@version(1, 0)
async def connect(req: ConnectRequest) -> Any:
    args = ["netbird", "up", "--setup-key", req.setup_key]
    if req.management_url:
        args += ["--management-url", req.management_url]
    return run(args)


@app.post("/disconnect", status_code=status.HTTP_200_OK)
@version(1, 0)
async def disconnect() -> Any:
    return run(["netbird", "down"])


@app.get("/status", status_code=status.HTTP_200_OK)
@version(1, 0)
async def get_status() -> Any:
    # Detailed status as JSON for the UI to parse.
    return run(["netbird", "status", "--json"])


app = VersionedFastAPI(app, version="1.0.0", prefix_format="/v{major}.{minor}", enable_latest=True)

app.mount("/", StaticFiles(directory="static", html=True), name="static")

if __name__ == "__main__":
    # Run uvicorn with logging disabled so loguru can handle it.
    # 9132 (ZeroTier's BlueOS extension already uses 9131 on the host network).
    uvicorn.run(app, host="0.0.0.0", port=9132, log_config=None)
