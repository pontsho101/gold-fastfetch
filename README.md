# Gold Fastfetch Config

![License](https://img.shields.io/github/license/Lucenx9/gold-fastfetch?style=for-the-badge&color=gold)
![Shell](https://img.shields.io/badge/Shell-Bash-goldenrod?style=for-the-badge&logo=gnu-bash&logoColor=white)
![OS](https://img.shields.io/badge/OS-Arch%20Linux-1793d1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Fastfetch](https://img.shields.io/badge/Fastfetch-v2+-blueviolet?style=for-the-badge)

![Preview](assets/preview.png)

A feature-rich, self-contained Fastfetch configuration installer for Arch Linux.

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
git clone https://github.com/Lucenx9/fastfetch-cosmic.git
cd fastfetch-cosmic
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
