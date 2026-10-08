# android-tailscaled

A Magisk / KernelSU / APatch module that runs **upstream tailscaled** on rooted Android (arm64) in kernel TUN mode, with a WebUI.

- **Up to date**: CI builds the latest [tailscale](https://github.com/tailscale/tailscale) release daily, applying a small patch set ([`patches/`](patches)).
- **Plain CLI**: `tailscale` works as-is (`su -c 'tailscale status'`), no wrappers or extra flags.
- **Coexists** with VPN apps and root TPROXY proxies (e.g. MaterialXray): Tailscale's packet marks and routing rules stay clear of Android's and theirs.
- **WebUI** (KernelSU / APatch / MMRL): status, devices, exit node, preferences, daemon settings, logs.

## Install

1. Download the zip from [Releases](https://github.com/AetherMagee/android-tailscaled/releases/latest) and install it in your root manager. The daemon starts right away.
2. Log in from the WebUI, or run `su -c 'tailscale up'` and open the printed link.

Updates arrive through the root manager's built-in module updater.

## Usage

| | |
|---|---|
| `tailscale ...` | the normal Tailscale CLI |
| `tailscaled.service {start\|stop\|restart\|status\|log}` | manage the daemon |
| `/data/adb/tailscale/tailscaled.conf` | daemon settings (port, TUN/userspace, rule priority, extra flags) |
| `/data/adb/tailscale/` | node state, socket and logs; kept on uninstall |

Toggling the module in the root manager stops/starts the daemon immediately. A module that was disabled at boot needs a reboot (or the WebUI's Start button) after re-enabling.

### Routing priority

Tailscale installs one policy rule, `not fwmark 0x40000000/0x60000000 lookup 52`, at `IP_RULE_PRIORITY`:

- `9999` (default): after TPROXY proxies (MaterialXray's rule is at 9990, its probes at 9991-9998), before all of Android's own rules (10000+), so tailnet IPs win over VPN apps. Proxied apps reach the tailnet only if the proxy bypasses `100.64.0.0/10` (MaterialXray's "Bypass LAN"). With an exit node, the proxy's own upstream traffic goes through the exit node.
- `5270`: upstream's default, Tailscale before everything. MaterialXray refuses to start TPROXY with a rule ahead of its own.

## What the patches change

| Patch | Why |
|---|---|
| detect Android (`/dev/__properties__`) | gate the rest on Android |
| fwmark bits → 29-30 (`0x60000000`) | upstream's `0xff0000` overlaps netd's bits 16-20; MaterialXray uses 21-28 |
| connmark rules appended, not inserted at 1 | MaterialXray requires its guard first in mangle OUTPUT |
| single fall-through ip rule | Android keeps default routes in per-network tables, so upstream's `main` + `unreachable` rules cut tailscaled off |
| `TS_IP_POLICY_PREF_BASE` | make the priority configurable |
| socket/state in `/data/adb/tailscale` | `tailscale` CLI works without `--socket` |
| no-op OS DNS configurator | Android has no `resolv.conf` |
| netd's protected-from-VPN bit on tailscaled's sockets | VPN apps don't capture Tailscale's own traffic |
| Tailscale SSH as `root` | no `/etc/passwd`/`getent` on Android; toybox `id` lacks `-z`; Android PATH. Sessions start in `/data/adb/tailscale/home` with `/system/bin/sh` |

Also omitted from the build: `portlist` (no reporting of listening services to the control plane) and server-only features (AWS, Kubernetes, systemd, …).

## Limitations

- arm64 only.
- MagicDNS names don't resolve system-wide yet (Android resolves through netd). Tailnet IPs work; 100.100.100.100 answers direct queries.
- Tailscale SSH supports only the `root` user (`ssh root@<device>`); allow it in your tailnet policy.
- Advertising an exit node or subnet routes is untested.
- Android's per-app background network restrictions apply to tailnet traffic, the same as for any VPN.

## Building

```sh
./build.sh            # latest upstream release
./build.sh v1.104.1   # specific tag
```

Needs Go and git. Produces `dist/android-tailscaled-<tag>-r<REVISION>.zip`. Bump `REVISION` to release module-only changes.
