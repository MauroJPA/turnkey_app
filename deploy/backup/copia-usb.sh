#!/usr/bin/env bash
# Cópia semanal para um disco/pen USB CIFRADO (LUKS): o backup mais recente do
# PocketBase + o .env (segredos). Mantém as últimas 12 cópias.
#
#   bash backup/copia-usb.sh /mnt/gookie-usb
#
# O destino TEM de ser um ponto de montagem (nunca escreve no disco do servidor
# por engano) e deve estar cifrado com LUKS (ver LEIA-ME.md, passo 8). Depois da
# cópia, desmontar e guardar o USB FORA do servidor.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
DESTINO_RAIZ="${1:-}"
MANTER="${MANTER:-12}"
LOGS="$AQUI/logs"; mkdir -p "$LOGS"; LOG="$LOGS/copia-usb.log"
log() { echo "$(date '+%F %T') [${2:-INFO}] $1" | tee -a "$LOG"; }

[ -n "$DESTINO_RAIZ" ] || { echo "Uso: bash backup/copia-usb.sh /mnt/gookie-usb"; exit 1; }
mountpoint -q "$DESTINO_RAIZ" || { log "$DESTINO_RAIZ não é um disco montado. Liga o USB, desbloqueia (LUKS) e monta." ERRO; exit 1; }

ULTIMO="$(ls -t "$RAIZ"/data/backups/*.zip 2>/dev/null | head -n1 || true)"
[ -n "$ULTIMO" ] || { log "Não há backups em $RAIZ/data/backups." ERRO; exit 1; }

DEST="$DESTINO_RAIZ/GookieBackups"; mkdir -p "$DEST"
LIVRE=$(df --output=avail -B1 "$DEST" | tail -n1)
TAM=$(stat -c %s "$ULTIMO")
[ "$LIVRE" -gt $((TAM * 3)) ] || { log "Pouco espaço livre no USB." ERRO; exit 1; }

cp -f "$ULTIMO" "$DEST/" && [ "$(stat -c %s "$DEST/$(basename "$ULTIMO")")" = "$TAM" ] \
  || { log "A cópia $(basename "$ULTIMO") ficou com tamanho diferente." ERRO; exit 1; }
log "Copiado $(basename "$ULTIMO") ($(du -h "$ULTIMO" | cut -f1)) para $DEST"

if [ -f "$RAIZ/.env" ]; then
  cp -f "$RAIZ/.env" "$DEST/env-ultimo.txt" && chmod 600 "$DEST/env-ultimo.txt"
  log ".env copiado (o USB tem de estar cifrado)."
fi

ls -t "$DEST"/*.zip 2>/dev/null | tail -n +$((MANTER + 1)) | while read -r f; do rm -f "$f"; log "Removida cópia antiga $(basename "$f")"; done
sync
log "Concluído. Desmonta o USB (umount) e guarda-o fora do servidor."
