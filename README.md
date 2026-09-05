# JB Toolbox v0.1 Core

A modular jailbreak utility app for **rootless iOS 15+** (designed for Dopamine/Procursus style environments).

## Included in v0.1
- Overview: device, iOS, kernel, uptime, storage, jailbreak root/bootstrap detection.
- Process Viewer: process names + PIDs with search and refresh.
- Actions: Respring, Userspace Reboot, uicache refresh, each behind confirmation.
- Rootless Theos packaging (`THEOS_PACKAGE_SCHEME = rootless`).
- GitHub Actions workflow that builds a `.deb` artifact.

## Build on a jailbroken iPhone
Install Theos prerequisites (per Theos documentation) and Theos itself, then place an iOS SDK in `$THEOS/sdks/`.

```sh
cd JBToolbox-v0.1
make clean package FINALPACKAGE=1
```

The package will be written to `packages/`.

## GitHub build
1. Create a repository and upload this folder.
2. Push to `main` or manually run **Build Rootless DEB** under Actions.
3. Download the artifact named `JBToolbox-rootless-deb`.
4. Install the `.deb` using Sileo/Zebra or `dpkg -i` on the jailbroken device.

## Important note about privileged actions
The UI and command bridge are implemented, but the exact ability of `sbreload`, `launchctl reboot userspace`, and `uicache` to execute from an app process depends on the jailbreak/bootstrap privilege model. If a command returns a non-zero exit code, the next module should be a narrowly scoped privileged helper/daemon rather than giving the GUI broad root access.

## Planned modules
- Installed Apps / Bundle Inspector
- IPA metadata & entitlements inspector
- Package manager (`dpkg`) viewer
- Crash/log viewer
- File/path shortcuts
- Tweak inventory + per-tweak quick actions
