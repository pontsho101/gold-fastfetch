#!/usr/bin/env bash
# install.sh - Installer for Gold Fastfetch Config
# Version: 1.0 (Gold Edition)

set -euo pipefail

# 0. Check Root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[Error] Do not run this script as root/sudo.${NC}"
    exit 1
fi

# 0.1 Check Distro (Arch Only)
if [[ ! -f /etc/arch-release ]]; then
    echo -e "${RED}[Error] This script is explicitly designed for Arch Linux.${NC}"
    echo "Running on non-Arch systems may break your config."
    exit 1
fi

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# XDG paths
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fastfetch"

trap 'echo -e "\n${RED}[!] Installation aborted.${NC}"; exit 1' INT

# --- Argument Handling ---
USE_ICONS_ARG=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --icons) USE_ICONS_ARG=1 ;;
        --no-icons) USE_ICONS_ARG=0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${GREEN}==> Gold Fastfetch Installer v1.0${NC}"

# 1. Check Dependencies
if ! command -v fastfetch >/dev/null 2>&1; then
    echo -e "${RED}[Error] Fastfetch is not installed.${NC}"
    echo "Run: sudo pacman -S fastfetch"
    exit 1
fi

FF_RAW_VER=$(fastfetch --version 2>/dev/null || echo "0.0.0")
FF_MAJOR=$(echo "$FF_RAW_VER" | grep -oE '[0-9]+\.[0-9]+' | head -n1 | cut -d. -f1 || echo "0")
if [[ ! "$FF_MAJOR" =~ ^[0-9]+$ ]]; then FF_MAJOR=0; fi

if [[ "$FF_MAJOR" -lt 2 ]]; then
    echo -e "${YELLOW}[Warn] Fastfetch version ($FF_RAW_VER) seems outdated. v2+ recommended.${NC}"
fi

echo -e "${YELLOW}==> Checking optional dependencies...${NC}"
MISSING_DEPS=0
for cmd in lspci checkupdates; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${YELLOW}  [Warn] '$cmd' missing.${NC}"
        if [[ "$cmd" == "checkupdates" ]]; then
            echo -e "${YELLOW}         -> Install with: sudo pacman -S pacman-contrib${NC}"
        elif [[ "$cmd" == "lspci" ]]; then
            echo -e "${YELLOW}         -> Install with: sudo pacman -S pciutils${NC}"
        fi
        MISSING_DEPS=1
    fi
done
if [[ $MISSING_DEPS -eq 0 ]]; then echo -e "${GREEN}  -> All dependencies found.${NC}"; fi

# 2. Icon Capability Check
if [[ -n "$USE_ICONS_ARG" ]]; then
    USE_ICONS=$USE_ICONS_ARG
else
    echo -e "${YELLOW}==> Checking font support...${NC}"
    echo -e "  Can you see this icon clearly? -> [   ]"
    read -r -p "  Enable Nerd Font icons? (y/N) " response
    if [[ $response =~ ^[Yy]$ ]]; then
        USE_ICONS=1
    else
        USE_ICONS=0
        echo -e "${YELLOW}  -> Icons disabled.${NC}"
        echo -e "${YELLOW}     Tip: To use icons, install a Nerd Font, set it as your terminal font,${NC}"
        echo -e "${YELLOW}          then run this installer again.${NC}"
    fi
fi

# 3. Backup
mkdir -p "$STATE_DIR/backups"
mkdir -p "$CONFIG_DIR"

REQUIRED_KB=10240
AVAILABLE_KB=$(df -Pk "$STATE_DIR" 2>/dev/null | awk 'NR==2{print $4}' || echo "99999999")

if (( AVAILABLE_KB < REQUIRED_KB )); then
    echo -e "${RED}[!] Insufficient space in $STATE_DIR ($AVAILABLE_KB KB available).${NC}"
    exit 1
fi

if [[ -d "$CONFIG_DIR" ]] && [[ -n "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
    BACKUP_PATH="$STATE_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}==> Backing up existing config to:${NC}"
    echo "    $BACKUP_PATH"

    mkdir -p "$BACKUP_PATH"

    if cp -a "$CONFIG_DIR/." "$BACKUP_PATH/"; then
        echo -e "${GREEN}  -> Backup successful.${NC}"
        # Keep only last 5 backups
        find "$STATE_DIR/backups" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | tail -n +6 | cut -d ' ' -f 2- | xargs -r rm -rf
    else
        echo -e "${RED}[!] Backup failed.${NC}"
        if [[ -t 0 ]]; then
            read -r -p "Continue anyway? (y/N) " response
            if [[ ! $response =~ ^[Yy]$ ]]; then exit 1; fi
        else
            exit 1
        fi
    fi
fi

# 4. Generate Helper Scripts

# --- gpu_detect.sh ---
cat << 'EOF' > "$CONFIG_DIR/gpu_detect.sh"
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

command -v lspci >/dev/null 2>&1 || { echo "N/A (lspci missing)"; exit 0; }
out=()

# NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && out+=("$line")
  done < <(
    nvidia-smi --query-gpu=name,memory.total,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null |
    awk -F',' '{
      for(i=1;i<=NF;i++){ gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if($1!=""){
        temp = ($3 != "" && $3 != "N/A") ? $3"°C" : "N/A"
        printf "%s [%.1f GiB] @ %s\n", $1, $2/1024, temp
      }
    }'
  )
fi

# Other GPUs
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ VMware ]] && continue
  if ((${#out[@]} > 0)); then [[ "$line" =~ NVIDIA ]] && continue; fi

  suffix=""
  if [[ "$line" =~ Intel ]] && [[ ! "$line" =~ Arc ]] && [[ ! "$line" =~ DG2 ]]; then
      suffix=" [Shared]"
  fi
  out+=("$line$suffix")
done < <(lspci 2>/dev/null | awk -F': ' '/(VGA|3D|Display)/{print $2}')

if ((${#out[@]} == 0)); then echo "N/A"; else (IFS=' | '; echo "${out[*]}"); fi
EOF

# --- updates.sh ---
cat << 'EOF' > "$CONFIG_DIR/updates.sh"
#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch"
CACHE_FILE="$CACHE_DIR/updates.txt"
LOCK_FILE="$CACHE_DIR/updates.lock"
CACHE_TTL=1800
LOCK_TIMEOUT=300

mkdir -p "$CACHE_DIR"

if [[ -e /var/lib/pacman/db.lck ]]; then
    echo "Repo: Locked | AUR: ?"
    exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }

count_updates() {
  local off=0 aur=0
  if have checkupdates; then
    off=$(timeout 10s checkupdates 2>/dev/null | wc -l || true); off=${off//[[:space:]]/}; off=${off:-0}
  else off="0"; fi

  if have yay; then
    aur=$(timeout 10s yay -Qua 2>/dev/null | wc -l || true); aur=${aur//[[:space:]]/}; aur=${aur:-0}
  elif have paru; then
    aur=$(timeout 10s paru -Qua 2>/dev/null | wc -l || true); aur=${aur//[[:space:]]/}; aur=${aur:-0}
  else aur="0"; fi
  echo "Repo: $off | AUR: $aur" > "$CACHE_FILE"
}

should_refresh() {
  [[ ! -f "$CACHE_FILE" ]] && return 0
  
  local file_time pacman_time now age
  file_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  
  # Smart Check: If pacman DB changed recently, refresh immediately
  pacman_time=$(stat -c %Y "/var/lib/pacman/local" 2>/dev/null || echo 0)
  if (( pacman_time > file_time )); then return 0; fi

  now=$(date +%s)
  age=$((now - file_time))
  (( age > CACHE_TTL ))
}

if [[ -d "$LOCK_FILE" ]]; then
  lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if (( lock_age > LOCK_TIMEOUT )); then rmdir "$LOCK_FILE" 2>/dev/null || true; fi
fi

# First run: sync, subsequent: async
if [[ ! -f "$CACHE_FILE" ]]; then
  count_updates
elif should_refresh; then
  ( if mkdir "$LOCK_FILE" 2>/dev/null; then
      trap 'rmdir "$LOCK_FILE" 2>/dev/null || true' EXIT
      count_updates
    fi ) >/dev/null 2>&1 &
fi
cat "$CACHE_FILE"
EOF

# --- disk_detect.sh ---
cat << 'DISKEOF' > "$CONFIG_DIR/disk_detect.sh"
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RED=$'\e[31m'
GRAY=$'\e[90m'
RESET=$'\e[0m'

make_bar() {
    local pct="${1%\%}"
    if ! [[ "$pct" =~ ^[0-9]+$ ]]; then pct=0; fi
    local filled=$((pct * 10 / 100))
    local empty=$((10 - filled))
    local color="$GREEN"
    if ((pct >= 90)); then color="$RED"; elif ((pct >= 70)); then color="$YELLOW"; fi
    local bar=""; for ((i=0; i<filled; i++)); do bar+="━"; done
    printf "%s%s%s" "$color" "$bar" "$RESET"
    bar=""; for ((i=0; i<empty; i++)); do bar+="━"; done
    printf "%s%s%s" "$GRAY" "$bar" "$RESET"
}

get_label() {
    local mount="$1"
    local fslabel="$2"
    if [[ -n "$fslabel" && "$fslabel" != "-" ]]; then
        echo "${fslabel,,}" | sed 's/^./\U&/'
        return
    fi
    case "${mount,,}" in
        /) echo "System" ;; /home) echo "Home" ;; /mnt/*) echo "${mount##*/}" ;; *) echo "${mount##*/}" ;;
    esac
}

to_gib() {
    local val="$1"
    [[ "$val" == "0B" || "$val" == "-" ]] && { echo "0.0"; return; }
    local num="${val%[GMKT]*}"; local suffix="${val##*[0-9.]}"
    case "$suffix" in
        G) awk "BEGIN{printf \"%.1f\", $num}" ;;
        M) awk "BEGIN{printf \"%.1f\", $num/1024}" ;;
        K) awk "BEGIN{printf \"%.1f\", $num/1048576}" ;;
        T) awk "BEGIN{printf \"%.1f\", $num*1024}" ;;
        *) awk "BEGIN{printf \"%.1f\", $num}" ;;
    esac
}

declare -A seen_sizes
first=1; disk_num=1

while IFS= read -r line; do
    read -r mount fstype size used percent fslabel <<< "$line"

    [[ "$mount" =~ ^/boot ]] && continue
    [[ "$mount" =~ ^/run ]] && continue
    [[ "$mount" =~ ^/dev ]] && continue
    [[ "$mount" =~ ^/sys ]] && continue
    [[ "$mount" =~ ^/proc ]] && continue
    [[ "$mount" =~ ^/var ]] && continue
    [[ "$mount" =~ \.snapshots ]] && continue
    # [[ "$mount" == "/home" ]] && continue

    # Deduplicate btrfs subvolumes by size
    if [[ "$fstype" == "btrfs" ]]; then
        if [[ -n "${seen_sizes[$size]:-}" ]]; then continue; fi
        seen_sizes[$size]=1
    fi

    size_gib=$(to_gib "$size")
    used_gib=$(to_gib "$used")
    label=$(get_label "$mount" "$fslabel")
    bar=$(make_bar "$percent")

    if [[ $first -eq 0 ]]; then
        if (( (disk_num - 1) % 3 == 0 )); then printf "\n                   "; else printf " │ "; fi
    fi
    first=0
    printf "%s %s/%sG (%s) %s" "$label" "$used_gib" "$size_gib" "$percent" "$bar"
    ((disk_num++))
done < <(timeout 2s findmnt -rn -o TARGET,FSTYPE,SIZE,USED,USE%,LABEL --real --types notmpfs,nofuse.sshfs,nonfs,nocifs 2>/dev/null)
DISKEOF

chmod +x "$CONFIG_DIR/"*.sh

# 5. Generate Config
echo -e "${YELLOW}==> Generating config.jsonc...${NC}"

# Icon keys based on Nerd Font availability
if [[ $USE_ICONS -eq 1 ]]; then
    I_USER="󰟷 "; I_HOST="󰌢 "; I_TIME="󰃰 "; I_OS="󰏤 "; I_KER="󰌽 "; I_UP="󰥔 "
    I_UPD="󰚰 "; I_PKG="󰏖 "; I_AUR="󰣇 "; I_SH="󰟤 "; I_LOC="󰗊 "; I_DE="󰍹 "; I_WM="󰖩 "
    I_TERM=" "; I_FONT="󰛖 "; I_CPU="󰻠 "; I_GPU="󰢮 "; I_RAM="󰍛 "; I_SWAP="󰓡 "
    I_DISK="󰋊 "; I_DISP="󰍹 "; I_AUD="󰓃 "; I_THM="󰉼 "; I_ICO="󰀻 "; I_CUR="󰇀 "
    I_PAD="󰊗 "; I_IP="󰩟 "; I_PLAY="󰎈 "; I_MEDIA="󰝚 "; I_PAL="󰸱 "
else
    I_USER=""; I_HOST=""; I_TIME=""; I_OS=""; I_KER=""; I_UP=""
    I_UPD=""; I_PKG=""; I_AUR=""; I_SH=""; I_LOC=""; I_DE=""; I_WM=""
    I_TERM=""; I_FONT=""; I_CPU=""; I_GPU=""; I_RAM=""; I_SWAP=""
    I_DISK=""; I_DISP=""; I_AUD=""; I_THM=""; I_ICO=""; I_CUR=""
    I_PAD=""; I_IP=""; I_PLAY=""; I_MEDIA=""; I_PAL=""
fi

cat << EOF > "$CONFIG_DIR/config.jsonc"
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "small", "padding": { "top": 1, "left": 2, "right": 3 } },
  "display": {
    "separator": " ", "showErrors": false, "disableLinewrap": true,
    "color": { "keys": "cyan", "title": "light_magenta" },
    "brightColor": true, "key": { "width": 18 },
    "size": { "ndigits": 1, "binaryPrefix": "iec" },
    "temp": { "unit": "C", "ndigits": 0 },
    "duration": { "abbreviation": true },
    "bar": { "width": 10, "char": { "elapsed": "━", "total": "━" }, "border": { "left": "", "right": "" } },
    "percent": { "type": 3, "ndigits": 0 }
  },
  "modules": [
    { "type": "custom", "format": "╭──────────────────────────────────────────────────────────", "outputColor": "cyan" },

    { "type": "title", "key": "│ ${I_USER}User", "keyColor": "light_magenta", "format": "{user-name}" },
    { "type": "title", "key": "│ ${I_HOST}Host", "keyColor": "light_magenta", "format": "{host-name}" },
    { "type": "datetime", "key": "│ ${I_TIME}Time", "keyColor": "light_magenta", "format": "{year}-{month}-{day-in-month} {hour}:{minute}" },

    { "type": "custom", "format": "├──────────────────────────────────────────────────────────", "outputColor": "cyan" },

    { "type": "os", "key": "│ ${I_OS}OS", "keyColor": "cyan" },
    { "type": "kernel", "key": "│ ${I_KER}Kernel", "keyColor": "cyan" },
    { "type": "uptime", "key": "│ ${I_UP}Uptime", "keyColor": "cyan" },
    { "type": "command", "key": "│ ${I_UPD}Updates", "keyColor": "yellow", "text": "bash \"$CONFIG_DIR/updates.sh\"" },
    { "type": "packages", "key": "│ ${I_PKG}Packages", "keyColor": "cyan", "format": "{all} (pacman {pacman}, flatpak {flatpak-all})" },
    { "type": "command", "key": "│ ${I_AUR}AUR", "keyColor": "cyan", "text": "pacman -Qmq 2>/dev/null | wc -l" },
    { "type": "shell", "key": "│ ${I_SH}Shell", "keyColor": "cyan" },
    { "type": "locale", "key": "│ ${I_LOC}Locale", "keyColor": "cyan" },
    { "type": "de", "key": "│ ${I_DE}Desktop", "keyColor": "cyan" },
    { "type": "wm", "key": "│ ${I_WM}WM", "keyColor": "cyan" },
    { "type": "terminal", "key": "│ ${I_TERM}Terminal", "keyColor": "cyan" },
    { "type": "terminalfont", "key": "│ ${I_FONT}Term Font", "keyColor": "cyan" },

    { "type": "custom", "format": "├──────────────────────────────────────────────────────────", "outputColor": "green" },

    { "type": "cpu", "key": "│ ${I_CPU}CPU", "keyColor": "green", "format": "{name} ({cores-physical}C/{cores-logical}T) @ {freq-max}" },
    { "type": "command", "key": "│ ${I_GPU}GPU", "keyColor": "green", "text": "bash \"$CONFIG_DIR/gpu_detect.sh\"" },
    { "type": "memory", "key": "│ ${I_RAM}RAM", "keyColor": "green", "format": "{used} / {total} ({percentage})" },
    { "type": "swap", "key": "│ ${I_SWAP}Swap", "keyColor": "green", "format": "{used} / {total} ({percentage})" },
    { "type": "command", "key": "│ ${I_DISK}Disks", "keyColor": "green", "text": "bash \"$CONFIG_DIR/disk_detect.sh\"" },

    { "type": "custom", "format": "├──────────────────────────────────────────────────────────", "outputColor": "blue" },

    { "type": "display", "key": "│ ${I_DISP}Display", "keyColor": "blue", "format": "{name} {width}x{height} @ {refresh-rate}Hz" },
    { "type": "sound", "key": "│ ${I_AUD}Audio", "keyColor": "blue" },
    { "type": "theme", "key": "│ ${I_THM}Theme", "keyColor": "blue" },
    { "type": "icons", "key": "│ ${I_ICO}Icons", "keyColor": "blue" },
    { "type": "font", "key": "│ ${I_FONT}Sys Fonts", "keyColor": "blue" },
    { "type": "cursor", "key": "│ ${I_CUR}Cursor", "keyColor": "blue" },
    { "type": "gamepad", "key": "│ ${I_PAD}Gamepad", "keyColor": "blue" },
    { "type": "localip", "key": "│ ${I_IP}Local IP", "keyColor": "blue", "compact": true, "showIpv4": true, "showIpv6": false, "defaultRouteOnly": true },

    { "type": "custom", "format": "├──────────────────────────────────────────────────────────", "outputColor": "yellow" },
    { "type": "player", "key": "│ ${I_PLAY}Player", "keyColor": "yellow" },
    { "type": "media", "key": "│ ${I_MEDIA}Playing", "keyColor": "yellow" },

    { "type": "custom", "format": "├──────────────────────────────────────────────────────────", "outputColor": "magenta" },
    { "type": "colors", "key": "│ ${I_PAL}Palette", "keyColor": "magenta", "symbol": "circle" },
    { "type": "custom", "format": "╰──────────────────────────────────────────────────────────", "outputColor": "magenta" }
  ]
}
EOF



if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
    echo -e "${GREEN}==> Installation complete!${NC}"
    echo -e "Test it by running: ${YELLOW}fastfetch${NC}"
else
    echo -e "${RED}[Error] Failed to create config file.${NC}"
    exit 1
fi
