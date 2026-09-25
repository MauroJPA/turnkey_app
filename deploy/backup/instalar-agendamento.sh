#!/usr/bin/env bash
# Agenda a cópia noturna para a nuvem com um timer do systemd (todos os dias às
# 03:30, hora do servidor). Corre com o teu utilizador (é onde está o rclone.conf).
#
#   sudo bash backup/instalar-agendamento.sh            # instalar
#   sudo bash backup/instalar-agendamento.sh remover
#
# Ver o estado:   systemctl list-timers gookie-backup*   |   journalctl -u gookie-backup
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Corre com sudo."; exit 1; }
UTIL="${SUDO_USER:-root}"
AQUI="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "remover" ]; then
  systemctl disable --now gookie-backup.timer 2>/dev/null || true
  rm -f /etc/systemd/system/gookie-backup.service /etc/systemd/system/gookie-backup.timer
  systemctl daemon-reload
  echo "Removido."; exit 0
fi

cat > /etc/systemd/system/gookie-backup.service <<EOF
[Unit]
Description=Gookie - copia noturna do backup para a nuvem (cifrada)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=$UTIL
ExecStart=/usr/bin/env bash $AQUI/copia-externa.sh
EOF

cat > /etc/systemd/system/gookie-backup.timer <<EOF
[Unit]
Description=Gookie - copia noturna (03:30)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now gookie-backup.timer
echo "Instalado (utilizador: $UTIL). Testar já: sudo systemctl start gookie-backup.service ; journalctl -u gookie-backup -n 20"
