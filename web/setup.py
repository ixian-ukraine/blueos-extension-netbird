#!/usr/bin/env python3

import setuptools

setuptools.setup(
    name="nb-vpn",
    version="0.74.7",
    description="BlueOS extension for NetBird (WireGuard mesh VPN) connectivity.",
    license="MIT",
    install_requires=[
        "appdirs == 1.4.4",
        "fastapi == 0.63.0",
        "fastapi-versioning == 0.9.1",
        "loguru == 0.5.3",
        "uvicorn == 0.13.4",
        "aiofiles == 0.8.0",
    ],
)
