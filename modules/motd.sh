#!/bin/bash
# =============================================================================
# modules/motd.sh — Installe un MOTD dynamique personnalisé
# Peut être exécuté seul : bash modules/motd.sh [NomDuService]
# =============================================================================

SERVICE_NAME="${1:-$(hostname)}"
MOTD_FILE="/etc/profile.d/99-custom-motd.sh"

# Désactiver les MOTD par défaut
if [ -d /etc/update-motd.d ]; then
    chmod -x /etc/update-motd.d/* 2>/dev/null
fi
: > /etc/motd

# Le nom du service est écrit en tête du script, échappé pour bash
printf '#!/bin/bash\nSERVICE_LABEL=%q\n' "$SERVICE_NAME" > "$MOTD_FILE"

cat >> "$MOTD_FILE" << 'MOTD_SCRIPT'

# Uniquement pour un shell bash interactif : ni sh/dash, ni bash -lc dans un script
[ -n "$BASH_VERSION" ] || return 0 2>/dev/null || exit 0
[[ $- == *i* ]] || return 0

RESET="\e[0m"; BOLD="\e[1m"
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"
WHITE="\e[97m"; RED="\e[31m"; GRAY="\e[90m"

# Délai max des commandes qui peuvent bloquer (NFS figé, démon Docker ou pmxcfs bloqué)
_motd_run() { timeout -k 1 "$@" 2>/dev/null; }

# ── Infos de base ─────────────────────────────────────────────────────────────
HOSTNAME=$(hostname)
OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2)
[ -n "$OS_NAME" ] || OS_NAME=$(uname -s)
# IP de l'interface qui porte la route par défaut (évite les ponts Docker/LXC)
IP_ADDR=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src"){print $(i+1); exit}}')
[ -n "$IP_ADDR" ] || IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //')

VIRT=$(systemd-detect-virt 2>/dev/null)
if [ -z "$VIRT" ] && [ -r /run/systemd/container ]; then
    VIRT=$(cat /run/systemd/container)
fi
case "$VIRT" in
    lxc|lxc-libvirt)   VIRT_TYPE="LXC Container" ;;
    kvm|qemu)          VIRT_TYPE="KVM VM" ;;
    docker|podman)     VIRT_TYPE="Conteneur ${VIRT^}" ;;
    none|"")           VIRT_TYPE="Host / Bare Metal" ;;
    *)                 VIRT_TYPE="${VIRT^} VM" ;;
esac

# ── CPU / RAM ─────────────────────────────────────────────────────────────────
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
[ -n "$CPU_MODEL" ] || CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/^Model name/{print $2; exit}' | xargs)
CPU_CORES=$(nproc 2>/dev/null)
# « command » : ignore les alias (free='free -h') chargés avant ce script
RAM_TOTAL=$(command free -h 2>/dev/null | awk '/^Mem:/{print $2}')
RAM_USED=$(command free -h 2>/dev/null | awk '/^Mem:/{print $3}')
RAM_PCT=$(command free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/$2*100}')

if   [ "${RAM_PCT:-0}" -ge 85 ]; then RAM_COLOR="$RED"
elif [ "${RAM_PCT:-0}" -ge 60 ]; then RAM_COLOR="$YELLOW"
else RAM_COLOR="$GREEN"
fi

# ── Disques montés ────────────────────────────────────────────────────────────
# Systèmes de fichiers virtuels exclus ; profondeur de montage <= 2 (/, /mnt/data…)
DISKS=$(_motd_run 3 df -h \
        -x tmpfs -x devtmpfs -x overlay -x squashfs -x efivarfs -x fuse -x fuse.lxcfs \
        --output=target,size,used,avail,pcent \
    | tail -n +2 \
    | grep -v -E "^/(dev|sys|proc|run|snap)(/|\s)" \
    | awk '{
        mount=$1
        n = gsub("/","/",$1)
        if (n <= 2) print mount, $2, $3, $4, $5
    }')

# ── Utilisateurs locaux (UID >= 1000, hors nobody) ────────────────────────────
USERS=$(awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')
ROOT_SHELL=$(grep "^root:" /etc/passwd | cut -d: -f7)

# ── Services applicatifs actifs ───────────────────────────────────────────────
SERVICES=$(systemctl list-units --type=service --state=running --no-legend --no-pager --plain 2>/dev/null \
    | grep -v -E "(systemd|dbus|getty|ssh|cron|rsyslog|user@|accounts|polkit|networkd|resolved|udev|timesyncd|snapd|multipathd|fwupd|udisks|ModemManager|bluetooth|avahi|qemu-guest-agent|postfix|chrony|unattended-upgrades|rpcbind|lxcfs|irqbalance|packagekit|wpa_supplicant|NetworkManager)" \
    | awk '{print $1}' | sed 's/\.service//' | head -8 | tr '\n' ' ')

# ── Ports en écoute (hors SSH et RPC) ─────────────────────────────────────────
PORTS=$(ss -tln 2>/dev/null \
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
    while read -r MOUNT SIZE USED AVAIL PCT; do
        [ -z "$MOUNT" ] && continue
        PCT=${PCT%\%}
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
for u in $USERS; do
    USHELL=$(grep "^${u}:" /etc/passwd | cut -d: -f7)
    UGROUPS=$(id -nG "$u" 2>/dev/null | tr ' ' ',')
    echo -e "   ${GRAY}   ├─ ${CYAN}${u}${RESET}    shell: ${GRAY}${USHELL}${RESET}  groupes: ${GRAY}${UGROUPS}${RESET}"
done

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
    DOCKER_OUT=$(_motd_run 3 docker ps --format "{{.Names}}\t{{.Status}}\t{{.Image}}") || DOCKER_OUT=""
    if [ -n "$DOCKER_OUT" ]; then
        echo ""
        echo -e "   ${WHITE}🐳  Docker — containers en cours${RESET}"
        while IFS=$'\t' read -r cname cstatus cimage; do
            short_image=$(echo "$cimage" | awk -F'/' '{print $NF}' | cut -d: -f1)
            echo -e "   ${GRAY}   ├─ ${GREEN}● ${CYAN}${cname}${RESET}  ${GRAY}${cstatus}  (${short_image})${RESET}"
        done <<< "$DOCKER_OUT"
    fi
fi

# ── Proxmox VMs / LXC (root uniquement) ───────────────────────────────────────
if [ "$EUID" -eq 0 ] && { command -v qm &>/dev/null || command -v pct &>/dev/null; }; then
    PVE_ITEMS=()
    if command -v qm &>/dev/null; then
        while read -r vmid name status _; do
            [ "$status" = "running" ] && PVE_ITEMS+=("$(printf "VM %-4s  %-16s" "$vmid" "$name")")
        done < <(_motd_run 5 qm list | tail -n +2)
    fi
    if command -v pct &>/dev/null; then
        while read -r line; do
            ctid=$(awk '{print $1}' <<< "$line")
            status=$(awk '{print $2}' <<< "$line")
            ctname=$(awk '{print $NF}' <<< "$line")
            [ "$status" = "running" ] && PVE_ITEMS+=("$(printf "CT %-4s  %-16s" "$ctid" "$ctname")")
        done < <(_motd_run 5 pct list | tail -n +2)
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
unset -f _motd_run
MOTD_SCRIPT

chmod 644 "$MOTD_FILE"

echo -e " \e[32m✔\e[0m MOTD installé pour : ${SERVICE_NAME}"
