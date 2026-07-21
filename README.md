# nb-vpn — NetBird VPN BlueOS extension

A [BlueOS Extension](https://blueos.cloud/docs/blueos/1.1/extensions/) that runs a
[NetBird](https://netbird.io/) client (WireGuard®-based mesh VPN with SSO/MFA and
access controls) on a BlueOS device, so you can reach the vehicle from anywhere.

Modeled on the [BlueOS-ZeroTier](https://github.com/BlueOS-community/BlueOS-ZeroTier)
extension — same skeleton (daemon + small FastAPI web UI wrapping the CLI), adapted
to NetBird's setup-key + management-URL model.

## Setup

1. In your NetBird dashboard (cloud `app.netbird.io`, or your **self-hosted** server),
   create a **setup key** (Settings → Setup Keys). Reusable keys are convenient for a fleet.
2. Install this extension on the vehicle.
3. Open the extension page and enter:
   - **Setup key** — from step 1.
   - **Management URL** — leave blank for NetBird cloud, or set your self-hosted
     management server URL (e.g. `https://netbird.example.com`).
4. Click **Connect**. The status panel shows Management/Signal state, the vehicle's
   NetBird IP, and connected peers.
5. From any other device on the same NetBird network, reach BlueOS at the vehicle's
   NetBird IP (shown in the status panel / NetBird dashboard).

You can also pre-seed the connection at install time via the extension's custom
settings by setting the env vars `NB_SETUP_KEY` and (optionally) `NB_MANAGEMENT_URL`
— the entrypoint runs `netbird up` with them on start.

## How it works

- **Daemon:** the container starts `netbird service run` (background), waits until
  `netbird status --check live` succeeds, then launches the web UI.
- **Web UI** (`:9132`, FastAPI + Vue): `POST /v1.0/connect` (`netbird up --setup-key …
  [--management-url …]`), `POST /v1.0/disconnect` (`netbird down`), `GET /v1.0/status`
  (`netbird status --json`).
- **Persistence:** config/state live in `/var/lib/netbird`, bind-mounted from
  `/usr/blueos/extensions/nb-vpn`, so the connection survives restarts and updates.

## Design decisions

- **Configurable URL + setup key** (not interactive SSO). Vehicles are headless, so a
  setup key is the practical auth. A Management URL field makes it work with both
  NetBird cloud and a self-hosted server from the same image.
- **`python:3.11-slim` + NetBird APT repo**, pinned to a specific `NETBIRD_VERSION`
  (build arg). Mirrors the ZeroTier extension's "install into a slim base + add a web
  UI" approach.
- **`systemctl` no-op shim** in the image: NetBird's `.deb` postinst calls `systemctl`,
  which doesn't exist in a container. The shim lets the install succeed; we run the
  daemon ourselves (no systemd).
- **`NB_CONFIG=/var/lib/netbird/config.json`**: the APT package otherwise defaults
  config to `/etc/netbird/`, which is *not* on the persistent bind mount — this keeps
  the config with the state so it persists.
- **Auto-connect is guarded**: `netbird up` only runs on start when `NB_SETUP_KEY` is
  set or a config already exists, so a fresh install never blocks on interactive login;
  the web UI drives the first connection.
- **Healthcheck = daemon liveness** (`netbird status --check live`), so the extension
  reports healthy right after install, before it's configured (matching the ZeroTier
  extension's behavior).

## Ports & permissions

- **9132** — web UI / API (ZeroTier's extension uses 9131; nb-vpn uses 9132 so both can run together).
- Runs `Privileged`, `NetworkMode: host`, `CapAdd: [NET_ADMIN, SYS_ADMIN]`, with the
  `/dev/net/tun` device (WireGuard needs a TUN interface).

## Build

```sh
docker build -t nb-vpn .
# pin a different NetBird version:
docker build --build-arg NETBIRD_VERSION=0.74.7 -t nb-vpn .
```

Multi-arch build/publish is handled by `.github/workflows/deploy.yml`
(`BlueOS-community/Deploy-BlueOS-Extension`, image name `nb-vpn`).

## TODO before publishing

- Update the repo/owner placeholders (`pinnokio/nb-vpn`) in the `Dockerfile` labels,
  `register_service`, and this README to the real GitHub repo.
- Set `DOCKER_USERNAME` / `DOCKER_PASSWORD` (and, for Bazaar, a `BCLOUD_PAT` +
  extension UUID) in the repo's Actions secrets.
