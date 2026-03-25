# Kexec tools for Android

Magisk module that installs [kexec-tools](https://git.kernel.org/pub/scm/utils/kernel/kexec/kexec-tools.git/) for Android. Installs `kexec` to `/system/bin/` via Magisk's systemless overlay.

Supported architectures: ARM64, ARM, x86_64, x86.

## Prerequisites

- Android device with [Magisk](https://github.com/topjohnwu/Magisk) v20.4+ installed

## Installation

### From release (recommended)

1. Download the latest `kexec-*.zip` from the [releases page](https://github.com/evdenis/kexec/releases)
2. Open **Magisk** → **Modules** → **Install from storage** → select the zip → **Reboot**

Supports auto-update via Magisk's built-in update mechanism.

### From source

```bash
git clone https://github.com/evdenis/kexec
cd kexec
make build-kexec-all
make install
```

Requires Docker (for cross-compilation), `adb` with USB debugging enabled, and root access on the device.

## Support

- [Telegram](https://t.me/joinchat/GsJfBBaxozXvVkSJhm0IOQ)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/module-debugging-modules-adb-root-t4050041)
