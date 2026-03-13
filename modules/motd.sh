#!/bin/bash
# =============================================================================
# modules/motd.sh — Installe un MOTD dynamique personnalisé
# Peut être exécuté seul : bash modules/motd.sh [NomDuService]
# =============================================================================

SERVICE_NAME="${1:-$(hostname)}"

# Désactiver les MOTD par défaut
if [ -d /etc/update-motd.d ]; then
    chmod -x /etc/update-motd.d/* 2>/dev/null
fi
> /etc/motd

cat > /etc/profile.d/99-custom-motd.sh << 'MOTD_SCRIPT'
#!/bin/bash

RESET="\e[0m"; BOLD="\e[1m"
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"
WHITE="\e[97m"; RED="\e[31m"; GRAY="\e[90m"

# ── Infos de base ─────────────────────────────────────────────────────────────
HOSTNAME=$(hostname)
OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')

if [ -f /run/systemd/container ]; then
    VIRT_TYPE="LXC Container"
elif systemd-detect-virt --quiet 2>/dev/null; then
    VIRT_TYPE="$(systemd-detect-virt 2>/dev/null | sed 's/\b./\u&/') VM"
else
    VIRT_TYPE="Host / Bare Metal"
fi

# ── CPU / RAM ─────────────────────────────────────────────────────────────────
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
CPU_CORES=$(nproc 2>/dev/null)
RAM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')
RAM_USED=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}')
RAM_PCT=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/$2*100}')

if   [ "${RAM_PCT:-0}" -ge 85 ]; then RAM_COLOR="$RED"
elif [ "${RAM_PCT:-0}" -ge 60 ]; then RAM_COLOR="$YELLOW"
else RAM_COLOR="$GREEN"
fi

# ── Disques montés ────────────────────────────────────────────────────────────
# - Exclut tmpfs, overlay, squashfs, devtmpfs, udev
# - Exclut les pseudo-fs système (/dev, /sys, /proc, /run)
# - Exclut les sous-montages (garde seulement les points de montage à ≤ 2 niveaux
#   ou les disques physiques identifiables)
# - Supprime la ligne header avec grep -v "^Mounted"
DISKS=$(df -h --output=target,size,used,avail,pcent 2>/dev/null \
    | grep -v -E "^(Mounted|tmpfs|devtmpfs|overlay|squashfs|udev)" \
    | grep -v -E "^\s*(Filesystem)" \
    | grep -v -E "^/(dev|sys|proc|run|snap)(\s|/)" \
    | awk '{
        mount=$1
        # Compter le nombre de "/" dans le chemin de montage
        n = gsub("/","/",$1)
        # Garder seulement les montages avec <= 2 niveaux de profondeur
        # ex: /  /boot  /mnt/data  → oui
        # ex: /mnt/Nas/APP_DATA/Plex → non
        if (n <= 2) print mount, $2, $3, $4, $5
    }')

# ── Utilisateurs locaux (UID >= 1000, hors nobody) ────────────────────────────
USERS=$(awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')
ROOT_SHELL=$(grep "^root:" /etc/passwd | cut -d: -f7)

# ── Services applicatifs actifs ───────────────────────────────────────────────
SERVICES=$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null \
    | grep -v -E "(systemd|dbus|getty|ssh|cron|rsyslog|user@|accounts|polkit|networkd|resolved|udev|timesyncd|snapd|multipathd|fwupd|udisks|ModemManager|bluetooth|avahi)" \
    | awk '{print $1}' | sed 's/\.service//' | head -8 | tr '\n' ' ')

# ── Ports en écoute (hors SSH et RPC) ─────────────────────────────────────────
PORTS=$(ss -tlnp 2>/dev/null \
    | awk 'NR>1 {split($4,a,":"); print a[length(a)]}' \
    | sort -nu \
    | grep -v -E "^(22|111)$" \
    | head -10 | tr '\n' ' ')

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e " ${BOLD}${GREEN}${SERVICE_LABEL}${RESET}  ${GRAY}[${VIRT_TYPE}]${RESET}"
echo -e " ${GRAY}────────────────────────────────────────────────────${RESET}"
echo -e "   ${WHITE}🖥️   OS        ${RESET}${BOLD}${GREEN}${OS_NAME}${RESET}"
echo -e "   ${WHITE}🏠  Hostname  ${RESET}${BOLD}${CYAN}${HOSTNAME}${RESET}"
echo -e "   ${WHITE}💡  IP        ${RESET}${BOLD}${YELLOW}${IP_ADDR}${RESET}"
echo -e "   ${WHITE}⚙️   Kernel    ${RESET}${GRAY}${KERNEL}${RESET}"
echo -e "   ${WHITE}⏱️   Uptime    ${RESET}${GRAY}${UPTIME}${RESET}"
echo ""
echo -e "   ${WHITE}🔲  CPU       ${RESET}${GRAY}${CPU_MODEL} (${CPU_CORES} cores)${RESET}"
echo -e "   ${WHITE}🧠  RAM       ${RESET}${RAM_COLOR}${RAM_USED} / ${RAM_TOTAL} (${RAM_PCT}%)${RESET}"

if [ -n "$DISKS" ]; then
    echo ""
    echo -e "   ${WHITE}💾  Disques montés${RESET}"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        MOUNT=$(echo "$line" | awk '{print $1}')
        SIZE=$(echo  "$line" | awk '{print $2}')
        USED=$(echo  "$line" | awk '{print $3}')
        AVAIL=$(echo "$line" | awk '{print $4}')
        PCT=$(echo   "$line" | awk '{print $5}' | tr -d '%')
        # Vérifier que PCT est bien un nombre avant la comparaison
        if [[ "$PCT" =~ ^[0-9]+$ ]]; then
            if   [ "$PCT" -ge 85 ]; then DCOL="$RED"
            elif [ "$PCT" -ge 60 ]; then DCOL="$YELLOW"
            else DCOL="$GREEN"
            fi
        else
            DCOL="$GREEN"
        fi
        echo -e "   ${GRAY}   ├─ ${CYAN}${MOUNT}${RESET}  ${DCOL}${USED}/${SIZE} (${PCT}%) — ${AVAIL} libres${RESET}"
    done <<< "$DISKS"
fi

echo ""
echo -e "   ${WHITE}👤  Utilisateurs${RESET}"
echo -e "   ${GRAY}   ├─ ${CYAN}root${RESET}    shell: ${GRAY}${ROOT_SHELL}${RESET}"
if [ -n "$USERS" ]; then
    for u in $USERS; do
        USHELL=$(grep "^${u}:" /etc/passwd | cut -d: -f7)
        UGROUPS=$(id "$u" 2>/dev/null | grep -oP "(?<=groups=).*" | grep -oP '\(\K[^)]+' | tr '\n' ',' | sed 's/,$//')
        echo -e "   ${GRAY}   ├─ ${CYAN}${u}${RESET}    shell: ${GRAY}${USHELL}${RESET}  groupes: ${GRAY}${UGROUPS}${RESET}"
    done
fi

if [ -n "$SERVICES" ]; then
    echo ""
    echo -e "   ${WHITE}🔧  Services actifs${RESET}"
    for svc in $SERVICES; do
        echo -e "   ${GRAY}   ├─ ${GREEN}● ${RESET}${svc}"
    done
fi

if [ -n "$PORTS" ]; then
    echo ""
    echo -e "   ${WHITE}🔌  Ports en écoute  ${GRAY}(hors SSH/111)${RESET}"
    echo -e "   ${GRAY}   └─ ${YELLOW}${PORTS}${RESET}"
fi

echo ""
MOTD_SCRIPT

sed -i "s|SERVICE_LABEL|${SERVICE_NAME}|g" /etc/profile.d/99-custom-motd.sh
chmod +x /etc/profile.d/99-custom-motd.sh

echo -e " \e[32m✔\e[0m MOTD installé pour : ${SERVICE_NAME}"