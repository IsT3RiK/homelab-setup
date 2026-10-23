#!/bin/bash
# =============================================================================
# modules/aliases.sh — Installe les aliases utiles pour Debian/Ubuntu
# Peut être exécuté seul : bash modules/aliases.sh
# =============================================================================

ALIASES_FILE="/etc/profile.d/98-homelab-aliases.sh"

# Couleurs
GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"

cat > "$ALIASES_FILE" << 'ALIASES'
#!/bin/bash
# ── Homelab aliases — IsT3RiK ─────────────────────────────────────────────────

# Uniquement pour un shell bash interactif
[ -n "$BASH_VERSION" ] || return 0 2>/dev/null || exit 0
[[ $- == *i* ]] || return 0

# Navigation / listing
alias ll='ls -lhF --color=auto'
alias la='ls -lhAF --color=auto'
alias lt='ls -lhFt --color=auto'          # trié par date
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# Sécurité / confirmation
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Réseau
alias ports='ss -tlnp'                     # ports en écoute
alias myip='hostname -I | awk "{print \$1}"'
alias ping='ping -c 4'

# Système
alias df='df -h'
alias du='du -h'
alias du1='du -h --max-depth=1'            # taille des sous-dossiers
alias free='free -h'
alias psf='ps auxf'                        # arbre des processus
command -v htop &>/dev/null && alias top='htop'

# Logs (journald si rsyslog absent, cas par défaut depuis Debian 12)
if [ -f /var/log/syslog ]; then
    alias syslog='tail -f /var/log/syslog'
else
    alias syslog='journalctl -f'
fi
if [ -f /var/log/auth.log ]; then
    alias authlog='tail -f /var/log/auth.log'
else
    alias authlog='journalctl -f _COMM=sshd _COMM=sshd-session _COMM=sudo _COMM=su'
fi
alias journald='journalctl -f'

# Services systemd
alias s='systemctl'
alias ss-status='systemctl status'
alias ss-restart='systemctl restart'
alias ss-start='systemctl start'
alias ss-stop='systemctl stop'
alias ss-enable='systemctl enable --now'
alias ss-log='journalctl -u'              # ex: ss-log nginx

# Docker (si installé)
if command -v docker &>/dev/null; then
    alias dc='docker compose'
    alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias dlogs='docker logs -f'
    alias dexec='docker exec -it'
fi

# Git
alias g='git'
alias gs='git status'
alias gp='git pull'
alias gpush='git push'
alias glog='git log --oneline --graph --decorate -20'

# Utilitaires
alias h='history | grep'
alias path='echo $PATH | tr ":" "\n"'
alias reload='source ~/.bashrc && source /etc/profile.d/98-homelab-aliases.sh'
alias cls='clear'
ALIASES

chmod 644 "$ALIASES_FILE"

echo -e " ${GREEN}✔${RESET} Aliases installés dans ${ALIASES_FILE}"
echo -e " ${YELLOW}→${RESET} Actifs dès la prochaine connexion SSH (ou : source ${ALIASES_FILE})"
