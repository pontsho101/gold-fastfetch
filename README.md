# Gold Fastfetch Config

![License](https://img.shields.io/github/license/Lucenx9/gold-fastfetch?style=for-the-badge&color=gold)
![Shell](https://img.shields.io/badge/Shell-Bash-goldenrod?style=for-the-badge&logo=gnu-bash&logoColor=white)
![OS](https://img.shields.io/badge/OS-Arch%20Linux-1793d1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Fastfetch](https://img.shields.io/badge/Fastfetch-v2+-blueviolet?style=for-the-badge)

![Preview](assets/preview.png)

A feature-rich, self-contained Fastfetch configuration installer for Arch Linux.

### ⚡ Quick Install
One-line command (safe & easy):
```bash
bash <(curl -sL https://raw.githubusercontent.com/Lucenx9/gold-fastfetch/main/install.sh)
```

## Features

- **Auto GPU detection** - Nvidia (VRAM & Temp), AMD/Intel support
- **Auto disk detection** - Filesystem labels, colored progress bars (excludes network drives)
- **Update checker** - Cached pacman/AUR update counts (Arch Linux)
- **Icon toggle** - Auto-detects Nerd Fonts, with manual override
- **Smart backups** - Automatic backup rotation (keeps last 5)
- **XDG compliant** - Uses standard config/state/cache paths

## Compatibility

- **OS**: Optimized for **Arch Linux** (Update module requires `pacman`).
- **Terminal**: Requires a Nerd Font for icons (optional).
- **GPU**: Detailed stats (VRAM/Temp) supported on NVIDIA. Intel/AMD show model/shared status.

## Requirements

- **Fastfetch** v2+
- **pciutils** (for `lspci`)
- **pacman-contrib** (highly recommended for update detection)
- **Nerd Font** (recommended for icons)

```bash
sudo pacman -S fastfetch pciutils pacman-contrib
```

## Installation

```bash
git clone https://github.com/Lucenx9/gold-fastfetch.git
cd gold-fastfetch
chmod +x install.sh
./install.sh
```

### Options

```bash
./install.sh --icons      # Force icons ON
./install.sh --no-icons   # Force icons OFF
```

## What Gets Installed

| File | Location | Description |
|------|----------|-------------|
| `config.jsonc` | `~/.config/fastfetch/` | Main config |
| `gpu_detect.sh` | `~/.config/fastfetch/` | GPU detection script |
| `disk_detect.sh` | `~/.config/fastfetch/` | Disk detection script |
| `updates.sh` | `~/.config/fastfetch/` | Update checker (cached) |

## Backups

Existing configs are backed up to:
```
~/.local/state/fastfetch/backups/backup_YYYYMMDD_HHMMSS/
```

Only the last 5 backups are kept.

## License

Unlicense / Public Domain

## Technical Details 🛠️

### 🚀 Smart Caching (updates.sh)
- **Problem**: Running `checkupdates` or `yay` on every term launch is slow.
- **Solution**: The script creates a cache file with a **30-minute TTL**.
- **Smart Invalidation**: It checks `/var/lib/pacman/local`. If you update your system, the cache is **instantly invalidated**, ensuring you always see real-time data without performance penalties.

### 💾 Dynamic Disk Detection (disk_detect.sh)
- **Problem**: Hardcoding disk paths (`/`, `/home`) fails on multi-drive setups.
- **Solution**: The script uses `findmnt` to dynamically discover **real** physical partitions.
- **Filtering**: Automatically excludes pseudo-filesystems (`tmpfs`, `overlay`, `/boot`, `/run`).
- **Visuals**: Generates color-coded storage bars directly in Bash.

### ⚡ Installation Logic
1. **Safety First**: Checks for `root` (blocks execution), verifies `Arch Linux` via `/etc/arch-release`.
2. **Backups**: Automatically backs up existing configs to `~/.local/state/fastfetch/backups/`.
3. **Generation**: The `.jsonc` config is **generated at runtime**, allowing it to inject variables (like Icons ON/OFF) based on your choices.
