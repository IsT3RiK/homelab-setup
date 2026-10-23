#!/bin/bash
# =============================================================================
# setup.sh — Configuration initiale d'une VM / LXC Debian/Ubuntu
# Usage : bash <(curl -fsSL https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main/setup.sh) "NomDuService"
#     ou, depuis un clone : bash setup.sh "NomDuService"
# =============================================================================

SERVICE_NAME="${1:-$(hostname)}"
GITHUB_RAW="https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main"
MODULES=(aliases.sh motd.sh)

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
fail() { echo -e "   ${RED}✘${RESET} $1"; }

# Vérifier root
if [ "$EUID" -ne 0 ]; then
    fail "Ce script doit être exécuté en root."
    exit 1
fi

banner

# Modules du clone si présents, sinon téléchargés (cas du one-liner curl)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/modules/motd.sh" ] && [ -f "$SCRIPT_DIR/modules/aliases.sh" ]; then
    MODULES_DIR="$SCRIPT_DIR/modules"
    ok "Modules locaux : ${MODULES_DIR}"
else
    step "Téléchargement des modules..."
    if ! command -v curl &>/dev/null; then
        fail "curl est introuvable (apt install curl)"
        exit 1
    fi
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
    MODULES_DIR="$TMP_DIR/modules"
    mkdir -p "$MODULES_DIR"
    for m in "${MODULES[@]}"; do
        curl -fsSL "$GITHUB_RAW/modules/$m" -o "$MODULES_DIR/$m" || { fail "Impossible de télécharger $m"; exit 1; }
    done
    ok "Modules téléchargés"
fi

# ── Module 1 : Aliases ───────────────────────────────────────────────────────
step "Installation des aliases..."
if bash "$MODULES_DIR/aliases.sh"; then
    ok "Aliases installés"
else
    fail "Erreur lors de l'installation des aliases"
fi

# ── Module 2 : MOTD ──────────────────────────────────────────────────────────
step "Installation du MOTD pour : ${SERVICE_NAME}..."
if bash "$MODULES_DIR/motd.sh" "$SERVICE_NAME"; then
    ok "MOTD installé"
else
    fail "Erreur lors de l'installation du MOTD"
fi

echo ""
echo -e " ${BOLD}${GREEN}✔ Setup terminé !${RESET}"
echo -e " ${CYAN}→ Reconnecte-toi en SSH pour voir le résultat.${RESET}"
echo ""
