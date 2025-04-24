#!/bin/bash

# CONFIGURATION
TELEGRAM_BOT_TOKEN="XXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
TELEGRAM_CHAT_ID="-XXXXXXXXXX"
HOSTNAME="pve"
NOW=$(date "+%Y-%m-%d %H:%M")
CPU_CORES=$(nproc)
ONLINE=""
OFFLINE=""

# Uptime hôte
UPTIME_SEC=$(cut -d. -f1 /proc/uptime)
UPTIME_H=$((UPTIME_SEC / 3600))
UPTIME_M=$((UPTIME_SEC % 3600 / 60))
if [ "$UPTIME_H" -ge 24 ]; then
  D=$((UPTIME_H / 24))
  H=$((UPTIME_H % 24))
  UPTIME="${D}j$(printf "%02d" $H)h"
else
  UPTIME="${UPTIME_H}h$(printf "%02d" $UPTIME_M)"
fi

# Ressources hôte
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)
LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //')
MEM_TOTAL=$(free -m | awk '/Mem:/ { print $2 }')
MEM_USED=$(free -m | awk '/Mem:/ { print $3 }')
MEM_PERCENT=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/$MEM_TOTAL*100}")
DISK_INFO=$(df -h / | awk 'NR==2')
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{gsub("%", "", $5); print $5}')

# LXC Containers
for ID in $(pct list | awk 'NR>1 {print $1}'); do
  CONF="/etc/pve/lxc/${ID}.conf"
  NAME=$(awk -F': ' '/^hostname:/ {print $2}' "$CONF")
  STATUS=$(pct status "$ID" | awk '{print $2}')
  MEM_TOTAL_MB=$(pct config "$ID" | awk '/memory:/ {print $2}')
  [[ -z "$MEM_TOTAL_MB" ]] && MEM_TOTAL_MB=0

  if [ "$STATUS" = "running" ]; then
    # CPU usage from cgroup v2
    STAT_FILE="/sys/fs/cgroup/lxc/${ID}/cpu.stat"
    if [[ -f "$STAT_FILE" ]]; then
      USAGE1=$(awk '/usage_usec/ {print $2}' "$STAT_FILE")
      sleep 1
      USAGE2=$(awk '/usage_usec/ {print $2}' "$STAT_FILE")
      DELTA=$((USAGE2 - USAGE1))
      CPU=$(awk -v d="$DELTA" -v c="$CPU_CORES" 'BEGIN {printf "%.1f", d / 10000 / c}')
    else
      CPU="0"
    fi

    MEM_MB=$(pct exec "$ID" -- free -m | awk '/Mem:/ {print $3}' 2>/dev/null || echo "0")
    CT_UPTIME=$(pct exec "$ID" -- awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "0")
    UH=$((CT_UPTIME / 3600))
    UM=$((CT_UPTIME % 3600 / 60))
    if [ "$UH" -ge 24 ]; then
      D=$((UH / 24))
      H=$((UH % 24))
      UPTIME_FMT="${D}j$(printf "%02d" $H)h"
    else
      UPTIME_FMT="${UH}h$(printf "%02d" $UM)"
    fi

    ONLINE+="🟢 ${NAME} ${ID}
CPU ${CPU}%, RAM ${MEM_MB}/${MEM_TOTAL_MB} Mo, Uptime: ${UPTIME_FMT}"$'\n'
  else
    OFFLINE+="🔴 ${NAME} ${ID}
CPU 0%, RAM 0/${MEM_TOTAL_MB} Mo, Uptime: 0h00"$'\n'
  fi
done

# QEMU VMs
for ID in $(qm list | awk 'NR>1 {print $1}'); do
  CONF="/etc/pve/qemu-server/${ID}.conf"
  NAME=$(awk -F': ' '/^name:/ {print $2}' "$CONF")
  STATUS=$(qm status "$ID" | awk '{print $2}')

  if [ "$STATUS" = "running" ]; then
    INFO=$(qm status "$ID" --verbose)
    PID=$(echo "$INFO" | awk '/^pid:/ {print $2}')
    CPU="0"
    if [[ "$PID" =~ ^[0-9]+$ ]]; then
      CPU_LINE=$(ps -p "$PID" -o %cpu= 2>/dev/null)
      CPU=$(awk -v val="${CPU_LINE:-0}" 'BEGIN {printf "%.1f", val}')
    fi
    [[ "$CPU" == "0.0" ]] && CPU="0"

    MEM_USED=$(echo "$INFO" | awk '/^mem:/ {print int($2 / 1024 / 1024)}')
    MEM_TOTAL=$(echo "$INFO" | awk '/^maxmem:/ {print int($2 / 1024 / 1024)}')
    UPTIME_SEC=$(echo "$INFO" | awk '/^uptime:/ {print $2}')
    UH=$((UPTIME_SEC / 3600))
    UM=$((UPTIME_SEC % 3600 / 60))
    if [ "$UH" -ge 24 ]; then
      D=$((UH / 24))
      H=$((UH % 24))
      UPTIME_FMT="${D}j$(printf "%02d" $H)h"
    else
      UPTIME_FMT="${UH}h$(printf "%02d" $UM)"
    fi

    ONLINE+="🟢 ${NAME} ${ID}
CPU ${CPU}%, RAM ${MEM_USED}/${MEM_TOTAL} Mo, Uptime: ${UPTIME_FMT}"$'\n'
  else
    MEM_TOTAL=$(qm config "$ID" | awk '/^memory:/ {print $2}')
    [[ -z "$MEM_TOTAL" ]] && MEM_TOTAL=0
    OFFLINE+="🔴 ${NAME} ${ID}
CPU 0%, RAM 0/${MEM_TOTAL} Mo, Uptime: 0h00"$'\n'
  fi
done

# Format message Telegram
REPORT="📊 État de PVE [${HOSTNAME}] – ${NOW}

🖥️ Hôte ${HOSTNAME}
CPU : ${CPU_USAGE} %
Charge moyenne : ${LOAD_AVG}
RAM : ${MEM_PERCENT} % (${MEM_USED} Mo / ${MEM_TOTAL} Mo)
Disque : ${DISK_PERCENT} % (${DISK_USED} / ${DISK_TOTAL})
Uptime : ${UPTIME}

📦 VM & CT :

🟢 En ligne :
${ONLINE:-Aucun}

🔴 Hors ligne :
${OFFLINE:-Aucun}
"

# Envoi Telegram
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
     --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
     --data-urlencode "text=${REPORT}"
