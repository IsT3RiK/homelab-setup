# homelab-setup

Configuration initiale automatisée pour VMs et LXC Proxmox (Debian/Ubuntu), et pour les nœuds Proxmox eux-mêmes.

Un seul script pour déployer en quelques secondes :
- 🖥️ **MOTD dynamique** — infos système utiles à chaque connexion SSH
- ⚡ **Aliases** — commandes utiles prêtes à l'emploi

---

## Installation rapide

```bash
# Cloner et exécuter (en root) — les modules du clone sont utilisés tels quels
git clone https://github.com/IsT3RiK/homelab-setup.git
cd homelab-setup
bash setup.sh "Nom De La VM"
```

**Ou en one-liner sans cloner** (les modules sont téléchargés depuis `main`, `curl` requis) :
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main/setup.sh) "Nom De La VM"
```

Sans argument, le nom affiché est le hostname. Relancer le script met à jour l'installation existante.

---

## Ce qui est installé

### 🖥️ MOTD dynamique (`modules/motd.sh`)

Installé dans `/etc/profile.d/99-custom-motd.sh`, affiché à chaque connexion SSH :

```
 Nextcloud VM  [KVM VM]
 ────────────────────────────────────────────────────
   🖥️   OS        Debian GNU/Linux 13 (trixie)
   🏠  Hostname  nextcloud
   💡  IP        192.168.1.42
   ⚙️   Kernel    6.12.48+deb13-amd64
   ⏱️   Uptime    2 hours, 14 minutes

   🔲  CPU       Intel Core i7-8700 (4 cores)
   🧠  RAM       1.2Gi / 4.0Gi (30%)

   💾  Disques montés
      ├─ /           4.2G/20G (21%) — 14G libres
      ├─ /mnt/data   120G/500G (24%) — 356G libres

   👤  Utilisateurs
      ├─ root    shell: /bin/bash
      ├─ deploy  shell: /bin/bash  groupes: deploy,sudo,docker

   🔧  Services actifs
      ├─ ● nginx
      ├─ ● php8.4-fpm

   🔌  Ports en écoute  (hors SSH/111)
      └─ 80 443

   🐳  Docker — containers en cours
      ├─ ● nextcloud  Up 2 hours  (nextcloud)
      ├─ ● redis      Up 2 hours  (redis)
```

Sur un nœud Proxmox (en root), un bloc liste les VM et LXC démarrées, trois par ligne :

```
   📦  Proxmox — 4 VM/LXC en cours
   ● VM 100   nextcloud          ● VM 101   jellyfin           ● CT 200   pihole
   ● CT 201   nginx-proxy
```

Détails :
- **Type de machine** détecté par `systemd-detect-virt` : `LXC Container`, `KVM VM` ou `Host / Bare Metal`.
- **IP** : celle de l'interface qui porte la route par défaut (les ponts Docker et LXC sont ignorés).
- **Disques** : systèmes de fichiers virtuels exclus (tmpfs, overlay, squashfs, fuse…), montages jusqu'à deux niveaux (`/`, `/mnt/data`).
- **Services** : 8 services applicatifs au plus, les services système courants sont masqués.
- **Docker** : affiché seulement si Docker est installé et accessible à l'utilisateur.
- **Couleurs** : RAM et disques passent en **jaune** à 60 % et en **rouge** à 85 %.
- **Jamais bloquant** : `df`, `docker ps`, `qm list` et `pct list` ont un délai maximum (3 à 5 s). Un partage NFS figé ou un démon bloqué fait disparaître sa section au lieu de bloquer la connexion.
- **Shell bash interactif uniquement** : rien ne s'affiche dans `sh`/`dash` ni dans un `bash -lc` lancé par un script.

---

### ⚡ Aliases (`modules/aliases.sh`)

Installés dans `/etc/profile.d/98-homelab-aliases.sh` (tous les utilisateurs, shell bash interactif) :

| Alias | Commande | Description |
|-------|----------|-------------|
| `ll` | `ls -lhF --color=auto` | Listing détaillé |
| `la` | `ls -lhAF --color=auto` | Listing avec fichiers cachés |
| `lt` | `ls -lhFt --color=auto` | Listing trié par date |
| `l` | `ls -CF --color=auto` | Listing compact |
| `..` / `...` | `cd ..` / `cd ../..` | Remonter d'un ou deux niveaux |
| `~` | `cd ~` | Retour au dossier personnel |
| `rm` / `cp` / `mv` | `rm -i` / `cp -i` / `mv -i` | Confirmation avant écrasement ou suppression |
| `ports` | `ss -tlnp` | Ports en écoute |
| `myip` | `hostname -I` (1re IP) | IP locale |
| `ping` | `ping -c 4` | Ping limité à 4 paquets |
| `df` | `df -h` | Espace disque lisible |
| `du` | `du -h` | Tailles lisibles (`du -sh` fonctionne) |
| `du1` | `du -h --max-depth=1` | Taille des sous-dossiers |
| `free` | `free -h` | RAM lisible |
| `psf` | `ps auxf` | Arbre des processus |
| `top` | `htop` | Seulement si htop est installé |
| `syslog` | `tail -f /var/log/syslog` | Ou `journalctl -f` sans rsyslog |
| `authlog` | `tail -f /var/log/auth.log` | Ou journald (sshd, sudo, su) sans rsyslog |
| `journald` | `journalctl -f` | Journal en direct |
| `s` | `systemctl` | Raccourci systemctl |
| `ss-status` / `ss-restart` / `ss-start` / `ss-stop` | `systemctl status` / `restart` / `start` / `stop` | Gérer un service |
| `ss-enable` | `systemctl enable --now` | Activer et démarrer un service |
| `ss-log` | `journalctl -u` | Logs d'un service (ex. `ss-log nginx`) |
| `dc` | `docker compose` | Docker Compose (si Docker installé) |
| `dps` | `docker ps` formaté | Containers : nom, état, ports |
| `dlogs` | `docker logs -f` | Logs d'un container en direct |
| `dexec` | `docker exec -it` | Shell dans un container |
| `g` / `gs` / `gp` / `gpush` | `git` / `git status` / `git pull` / `git push` | Git |
| `glog` | `git log --oneline --graph --decorate -20` | Historique compact |
| `h` | `history \| grep` | Chercher dans l'historique |
| `path` | `echo $PATH` (une entrée par ligne) | Lire le PATH |
| `reload` | `source ~/.bashrc` + aliases | Recharger la configuration |
| `cls` | `clear` | Effacer l'écran |

---

## Utilisation des modules seuls

```bash
# Seulement le MOTD
bash modules/motd.sh "Nom Service"

# Seulement les aliases
bash modules/aliases.sh
```

---

## Déploiement sur plusieurs machines

```bash
for HOST in 192.168.1.40 192.168.1.41 192.168.1.42; do
    ssh root@$HOST "bash <(curl -fsSL https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main/setup.sh) 'Mon Service'"
done
```

---

## Structure

```
homelab-setup/
├── setup.sh          ← Script principal
├── modules/
│   ├── motd.sh       ← MOTD dynamique
│   └── aliases.sh    ← Aliases système
└── README.md
```

---

> Prévu pour Debian 12/13, Ubuntu 22.04/24.04 et Proxmox VE 8/9.
