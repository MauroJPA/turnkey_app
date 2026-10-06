#!/usr/bin/env bash
# Agenda a cópia noturna para a nuvem com um timer do systemd (todos os dias às
# 03:30, hora do servidor). Corre com o teu utilizador (é onde está o rclone.conf).
#
#   sudo bash backup/instalar-agendamento.sh            # instalar
#   sudo bash backup/instalar-agendamento.sh remover
#
# Ver o estado:   systemctl list-timers gc_turnkey-backup*   |   journalctl -u gc_turnkey-backup
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Corre com sudo."; exit 1; }
UTIL="${SUDO_USER:-root}"
AQUI="$(cd "$(dirname "$0")" && pwd)"

# unidades das instalações anteriores (antes de 1.7.0, chamavam-se "gookie-backup")
systemctl disable --now gookie-backup.timer 2>/dev/null || true
rm -f /etc/systemd/system/gookie-backup.service /etc/systemd/system/gookie-backup.timer

if [ "${1:-}" = "remover" ]; then
  systemctl disable --now gc_turnkey-backup.timer gc_turnkey-restauro.timer 2>/dev/null || true
  rm -f /etc/systemd/system/gc_turnkey-restauro.service /etc/systemd/system/gc_turnkey-restauro.timer
  rm -f /etc/systemd/system/gc_turnkey-backup.service /etc/systemd/system/gc_turnkey-backup.timer
  systemctl daemon-reload
  echo "Removido."; exit 0
fi

cat > /etc/systemd/system/gc_turnkey-backup.service <<EOF
[Unit]
Description=gc_turnkey - copia noturna do backup para a nuvem (cifrada)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=$UTIL
ExecStart=/usr/bin/env bash $AQUI/copia-externa.sh
EOF

cat > /etc/systemd/system/gc_turnkey-backup.timer <<EOF
[Unit]
Description=gc_turnkey - copia noturna (03:30)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
EOF

# teste de restauro automático: dia 1 de cada mês às 05:00 (arranca o backup num
# contentor descartável; não toca na produção) e regista o resultado para a app
cat > /etc/systemd/system/gc_turnkey-restauro.service <<EOF
[Unit]
Description=gc_turnkey - teste de restauro do ultimo backup
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=$UTIL
ExecStart=/usr/bin/env bash $AQUI/teste-restauro.sh
EOF

cat > /etc/systemd/system/gc_turnkey-restauro.timer <<EOF
[Unit]
Description=gc_turnkey - teste de restauro mensal (dia 1, 05:00)

[Timer]
OnCalendar=*-*-01 05:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now gc_turnkey-backup.timer gc_turnkey-restauro.timer
echo "Instalado (utilizador: $UTIL). Testar já: sudo systemctl start gc_turnkey-backup.service ; journalctl -u gc_turnkey-backup -n 20"
