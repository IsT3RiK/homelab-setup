#!/bin/bash
# =============================================================================
# setup.sh — Configuration initiale d'une VM / LXC Debian/Ubuntu
# Usage : bash setup.sh [NomDuService]
# Exemple : bash setup.sh "Nextcloud VM"
# =============================================================================

SERVICE_NAME="${1:-$(hostname)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"; BOLD="\e[1m"

banner() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║       homelab-setup by IsT3RiK           ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
    echo ""
}

step() { echo -e " ${BOLD}${GREEN}▶${RESET} $1"; }
ok()   { echo -e "   ${GREEN}✔${RESET} $1"; }
warn() { echo -e "   ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "   ${RED}✘${RESET} $1"; }

# Vérifier root
if [ "$EUID" -ne 0 ]; then
    fail "Ce script doit être exécuté en root."
    exit 1
fi

banner

# ── Module 1 : Aliases ───────────────────────────────────────────────────────
step "Installation des aliases..."
if bash "$SCRIPT_DIR/modules/aliases.sh"; then
    ok "Aliases installés"
else
    fail "Erreur lors de l'installation des aliases"
fi

# ── Module 2 : MOTD ──────────────────────────────────────────────────────────
step "Installation du MOTD pour : ${SERVICE_NAME}..."
if bash "$SCRIPT_DIR/modules/motd.sh" "$SERVICE_NAME"; then
    ok "MOTD installé"
else
    fail "Erreur lors de l'installation du MOTD"
fi

echo ""
echo -e " ${BOLD}${GREEN}✔ Setup terminé !${RESET}"
echo -e " ${CYAN}→ Reconnecte-toi en SSH pour voir le résultat.${RESET}"
echo ""
