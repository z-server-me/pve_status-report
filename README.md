## 🏋️ `pve_status_report.sh` – Rapport d’état PVE avec notification Telegram

Ce script génère un **rapport quotidien complet** de l’état de ton hôte **Proxmox VE (PVE)** ainsi que de toutes ses **VMs (QEMU)** et **CTs (LXC)**. Il envoie le tout directement dans ton **groupe Telegram**, joliment formaté.

---

### ✅ Fonctionnalités

- Affiche l’usage **CPU, RAM, disque** et **uptime** de l’hôte
- Liste toutes les **VMs et CTs en ligne** avec :
  - `% CPU` réel (via `ps` pour QEMU, `cpu.stat` pour LXC)
  - RAM utilisée / allouée
  - Uptime au format `7j18h` ou `1h32`
- Liste les VMs/CTs **hors ligne**
- **Compatibilité cgroup v2** pour LXC
- Envoie le rapport sur **Telegram** (bot + groupe)

---

### 🛠️ Prérequis

- Proxmox VE avec `bash`, `awk`, `curl`
- Un **bot Telegram** et l’**ID du groupe** dans lequel tu veux envoyer les rapports
- Système utilisant **cgroup v2** (cas détecté automatiquement)

---

### 📁 Installation

1. Place le script ici :
   ```bash
   /home/scripts/pve_status_report.sh
   ```

2. Rends-le exécutable :
   ```bash
   chmod +x /home/scripts/pve_status_report.sh
   ```

3. Ajoute-le à `crontab` pour une exécution automatique tous les matins à 8h :
   ```bash
   crontab -e
   ```

   Et ajoute :
   ```cron
   0 8 * * * /home/scripts/pve_status_report.sh
   ```

---

### ✏️ Configuration

Les deux variables suivantes doivent être correctement renseignées en haut du script :

```bash
TELEGRAM_BOT_TOKEN="TON_TOKEN_ICI"
TELEGRAM_CHAT_ID="TON_CHAT_ID_ICI"
```

---

### 📦 Exemple de sortie Telegram

```text
📊 État de PVE [pve] – 2025-04-23 17:10

🔥 Hôte pve
CPU : 2 %
Charge moyenne : 2.69, 2.83, 3.06
RAM : 76.9 % (7932 Mo / 16384 Mo)
Disque : 8 % (32G / 444G)
Uptime : 7j19h

📦 VM & CT :

🟢 En ligne :
🟢 jellyfin 20308096
CPU 1.6%, RAM 3817/8192 Mo, Uptime: 7j03h

🔴 Hors ligne :
🔴 kali 101
CPU 0%, RAM 0/8192 Mo, Uptime: 0h00
```

---

### 🧪 Debug & Astuces

- Si une valeur CPU LXC est absente ou aberrante, le script force `0%` par défaut
- Tu peux exécuter ce script manuellement à tout moment :
  ```bash
  bash /home/scripts/pve_status_report.sh
  ```
