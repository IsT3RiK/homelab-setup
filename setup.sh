#!/bin/bash
# =============================================================================
# setup.sh — Configuration initiale d'une VM / LXC Debian/Ubuntu
# Usage : bash <(curl -fsSL https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main/setup.sh) "NomDuService"
# =============================================================================

SERVICE_NAME="${1:-$(hostname)}"
GITHUB_RAW="https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main"
TMP_DIR=$(mktemp -d)

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

# Télécharger les modules dans un dossier temporaire
step "Téléchargement des modules..."
mkdir -p "$TMP_DIR/modules"

curl -fsSL "$GITHUB_RAW/modules/aliases.sh" -o "$TMP_DIR/modules/aliases.sh" || { fail "Impossible de télécharger aliases.sh"; exit 1; }
curl -fsSL "$GITHUB_RAW/modules/motd.sh"   -o "$TMP_DIR/modules/motd.sh"   || { fail "Impossible de télécharger motd.sh"; exit 1; }
chmod +x "$TMP_DIR/modules/aliases.sh" "$TMP_DIR/modules/motd.sh"
ok "Modules téléchargés"

# ── Module 1 : Aliases ───────────────────────────────────────────────────────
step "Installation des aliases..."
if bash "$TMP_DIR/modules/aliases.sh"; then
    ok "Aliases installés"
else
    fail "Erreur lors de l'installation des aliases"
fi

# ── Module 2 : MOTD ──────────────────────────────────────────────────────────
step "Installation du MOTD pour : ${SERVICE_NAME}..."
if bash "$TMP_DIR/modules/motd.sh" "$SERVICE_NAME"; then
    ok "MOTD installé"
else
    fail "Erreur lors de l'installation du MOTD"
fi

# Nettoyage
rm -rf "$TMP_DIR"

echo ""
echo -e " ${BOLD}${GREEN}✔ Setup terminé !${RESET}"
echo -e " ${CYAN}→ Reconnecte-toi en SSH pour voir le résultat.${RESET}"
echo ""