# homelab-setup

Configuration initiale automatisée pour VMs et LXC Proxmox (Debian/Ubuntu).

Un seul script pour déployer en quelques secondes :
- 🖥️ **MOTD dynamique** — infos système utiles à chaque connexion SSH
- ⚡ **Aliases** — commandes utiles prêtes à l'emploi

---

## Installation rapide

```bash
# Cloner et exécuter (en root)
git clone https://github.com/IsT3RiK/homelab-setup.git
cd homelab-setup
bash setup.sh "Nom De La VM"
```

**Ou en one-liner sans cloner :**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/IsT3RiK/homelab-setup/main/setup.sh) "Nom De La VM"
```

---

## Ce qui est installé

### 🖥️ MOTD dynamique (`modules/motd.sh`)

Affiché à chaque connexion SSH :

```
 Nextcloud VM  [KVM VM]
 ────────────────────────────────────────────────────
   🖥️   OS        Debian GNU/Linux 12 (bookworm)
   🏠  Hostname  nextcloud
   💡  IP        192.168.1.42
   ⚙️   Kernel    6.1.0-18-amd64
   ⏱️   Uptime    2 hours, 14 minutes

   🔲  CPU       Intel Core i7-8700 (4 cores)
   🧠  RAM       1.2G / 4.0G (30%)

   💾  Disques montés
      ├─ /           4.2G/20G (21%) — 14G libres
      ├─ /mnt/data   120G/500G (24%) — 356G libres

   👤  Utilisateurs
      ├─ root    shell: /bin/bash
      ├─ deploy  shell: /bin/bash  groupes: sudo,docker

   🔧  Services actifs
      ├─ ● nginx
      ├─ ● php8.2-fpm

   🔌  Ports en écoute  (hors SSH/111)
      └─ 80 443
```

Couleurs adaptatives : RAM et disques passent en **jaune** à 60% et **rouge** à 85%.

---

### ⚡ Aliases (`modules/aliases.sh`)

Installés dans `/etc/profile.d/` (disponibles pour tous les utilisateurs) :

| Alias | Commande | Description |
|-------|----------|-------------|
| `ll` | `ls -lhF --color=auto` | Listing détaillé |
| `la` | `ls -lhAF --color=auto` | Listing avec fichiers cachés |
| `lt` | `ls -lhFt --color=auto` | Listing trié par date |
| `..` | `cd ..` | Remonter un niveau |
| `ports` | `ss -tlnp` | Ports en écoute |
| `myip` | `hostname -I` | IP locale |
| `df` | `df -h` | Espace disque lisible |
| `free` | `free -h` | RAM lisible |
| `s` | `systemctl` | Raccourci systemctl |
| `ss-log` | `journalctl -u` | Logs d'un service |
| `dc` | `docker compose` | Docker Compose (si installé) |
| `dps` | `docker ps` formaté | Containers Docker |
| `h` | `history \| grep` | Chercher dans l'historique |

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

> Testé sur Debian 11/12 et Ubuntu 22.04/24.04
