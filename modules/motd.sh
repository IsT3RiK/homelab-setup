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
DISKS=$(df -h --output=target,size,used,avail,pcent 2>/dev/null \
    | grep -v -E "^(Mounted|tmpfs|devtmpfs|overlay|squashfs|udev)" \
    | grep -v -E "^\s*(Filesystem)" \
    | grep -v -E "^/(dev|sys|proc|run|snap)(\s|/)" \
    | awk '{
        mount=$1
        n = gsub("/","/",$1)
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
echo -e " ${BOLD}${GREEN}##SERVICE_LABEL##${RESET}  ${GRAY}[${VIRT_TYPE}]${RESET}"
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

# ── Docker containers ─────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    DOCKER_OUT=$(docker ps --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)
    if [ -n "$DOCKER_OUT" ]; then
        echo ""
        echo -e "   ${WHITE}🐳  Docker — containers en cours${RESET}"
        while IFS=$'\t' read -r cname cstatus cimage; do
            short_image=$(echo "$cimage" | awk -F'/' '{print $NF}' | cut -d: -f1)
            echo -e "   ${GRAY}   ├─ ${GREEN}● ${CYAN}${cname}${RESET}  ${GRAY}${cstatus}  (${short_image})${RESET}"
        done <<< "$DOCKER_OUT"
    fi
fi

# ── Proxmox VMs / LXC ─────────────────────────────────────────────────────────
if command -v qm &>/dev/null || command -v pct &>/dev/null; then
    PVE_ITEMS=()
    if command -v qm &>/dev/null; then
        while IFS= read -r line; do
            vmid=$(awk '{print $1}' <<< "$line")
            name=$(awk '{print $2}' <<< "$line")
            status=$(awk '{print $3}' <<< "$line")
            [ "$status" = "running" ] && PVE_ITEMS+=("$(printf "VM %-4s  %-16s" "$vmid" "$name")")
        done < <(qm list 2>/dev/null | tail -n +2)
    fi
    if command -v pct &>/dev/null; then
        while IFS= read -r line; do
            ctid=$(awk '{print $1}' <<< "$line")
            status=$(awk '{print $2}' <<< "$line")
            ctname=$(awk '{print $NF}' <<< "$line")
            [ "$status" = "running" ] && PVE_ITEMS+=("$(printf "CT %-4s  %-16s" "$ctid" "$ctname")")
        done < <(pct list 2>/dev/null | tail -n +2)
    fi
    if [ ${#PVE_ITEMS[@]} -gt 0 ]; then
        echo ""
        echo -e "   ${WHITE}📦  Proxmox — ${#PVE_ITEMS[@]} VM/LXC en cours${RESET}"
        col=0
        line_buf="   "
        for item in "${PVE_ITEMS[@]}"; do
            line_buf+="${GREEN}● ${CYAN}${item}${RESET}   "
            col=$((col + 1))
            if [ $((col % 3)) -eq 0 ]; then
                echo -e "$line_buf"
                line_buf="   "
                col=0
            fi
        done
        [ "$col" -gt 0 ] && echo -e "$line_buf"
    fi
fi

echo ""
MOTD_SCRIPT

sed -i "s|##SERVICE_LABEL##|${SERVICE_NAME}|g" /etc/profile.d/99-custom-motd.sh
chmod +x /etc/profile.d/99-custom-motd.sh

echo -e " \e[32m✔\e[0m MOTD installé pour : ${SERVICE_NAME}"
