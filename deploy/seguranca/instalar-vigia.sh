#!/usr/bin/env bash
# Instala o vigia de segurança do gc_turnkey: um timer do systemd que corre o
# vigia.py de 10 em 10 minutos, como root (só para poder LER os registos do
# sistema). O vigia só lê: não altera nada nem bloqueia ninguém.
#
#   sudo bash seguranca/instalar-vigia.sh            # instalar (e fazer a 1.ª ronda)
#   sudo bash seguranca/instalar-vigia.sh remover    # desligar (os dados ficam)
#
# Ver o que faz:   systemctl list-timers gc_turnkey-vigia
#                  journalctl -u gc_turnkey-vigia -n 20
#                  sudo python3 seguranca/vigia.py estado
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Corre com sudo."; exit 1; }
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
ESTADO=/var/lib/gc_turnkey-vigia
CONF=/etc/gc_turnkey-vigia.conf

if [ "${1:-}" = "remover" ]; then
  systemctl disable --now gc_turnkey-vigia.timer 2>/dev/null || true
  rm -f /etc/systemd/system/gc_turnkey-vigia.service /etc/systemd/system/gc_turnkey-vigia.timer
  systemctl daemon-reload
  echo "Vigia desligado. (O que aprendeu fica em $ESTADO e o resultado em $RAIZ/data/seguranca_vigia.json.)"
  exit 0
fi

command -v python3 >/dev/null || { echo "Falta o python3 (sudo apt install python3)."; exit 1; }
[ -f "$AQUI/vigia.py" ] || { echo "Não encontro $AQUI/vigia.py"; exit 1; }
mkdir -p "$RAIZ/data"

# pasta onde o vigia guarda o que aprendeu (só root)
mkdir -p "$ESTADO"
chmod 700 "$ESTADO"

# configuração opcional (só root a lê)
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EOF'
# Configuração do vigia de segurança do gc_turnkey (opcional).
#
# Aviso direto por Telegram (útil para saberes mesmo que a app esteja em baixo).
# A app também avisa sozinha pelos canais que configuraste em Configurações → Avisos;
# se puseres os dois, recebes cada alerta duas vezes.
# TELEGRAM_BOT_TOKEN=
# TELEGRAM_CHAT_ID=
#
# Endereços da internet de onde É NORMAL entrares por SSH (separados por vírgula,
# aceita redes: 203.0.113.0/24). Se o servidor só se acede pelo Tailscale/rede
# local, deixa vazio: qualquer entrada vinda da internet é alerta crítico.
# IPS_PERMITIDOS=
EOF
  chmod 600 "$CONF"
fi

cat > /etc/systemd/system/gc_turnkey-vigia.service <<EOF
[Unit]
Description=gc_turnkey - vigia de seguranca (so le; procura sinais de intrusao)
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/env python3 $AQUI/vigia.py --raiz $RAIZ --dados $RAIZ/data --estado-dir $ESTADO --conf $CONF
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=300
# so le o sistema; so escreve onde tem de escrever
ProtectSystem=strict
ReadWritePaths=$ESTADO $RAIZ/data
ProtectHome=read-only
NoNewPrivileges=true
ProtectKernelModules=true
ProtectControlGroups=true
EOF

cat > /etc/systemd/system/gc_turnkey-vigia.timer <<'EOF'
[Unit]
Description=gc_turnkey - vigia de seguranca (de 10 em 10 minutos)

[Timer]
OnBootSec=3min
OnUnitActiveSec=10min
AccuracySec=30s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now gc_turnkey-vigia.timer
echo "A fazer a 1.ª ronda (aprende o que é normal neste servidor)..."
systemctl start gc_turnkey-vigia.service || true
sleep 2
python3 "$AQUI/vigia.py" estado --raiz "$RAIZ" --dados "$RAIZ/data" --estado-dir "$ESTADO" | head -n 25 || true
echo
echo "Instalado. Vê na app: Configurações → Segurança e backups."
echo "IMPORTANTE: instala num servidor que SABES estar limpo — o que existir hoje fica como 'normal'."
echo "Quando fizeres uma mudança legítima (nova chave SSH tua, novo contentor...), na app carrega em 'Já verifiquei'."
