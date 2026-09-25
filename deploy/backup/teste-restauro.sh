#!/usr/bin/env bash
# Teste de restauro (fazer todos os meses): descarrega e DECIFRA o backup mais
# recente da nuvem (ou usa um ficheiro/USB), descompacta numa pasta temporária,
# arranca um contentor descartável do Gookie nessa pasta e confirma que responde.
# Não toca na produção.
#
#   bash backup/teste-restauro.sh                        # a partir da nuvem
#   bash backup/teste-restauro.sh /mnt/gookie-usb/GookieBackups   # pasta com .zip
#   bash backup/teste-restauro.sh /caminho/backup.zip
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
REMOTE="${REMOTE:-gookie-crypt:}"
PORTA="${PORTA:-18090}"
ORIGEM="${1:-}"
INICIO=$(date +%s)
TMP="$(mktemp -d /tmp/gookie-restauro.XXXXXX)"
trap 'docker rm -f gookie-restauro >/dev/null 2>&1; rm -rf "$TMP"' EXIT

command -v docker >/dev/null || { echo "Falta o Docker."; exit 1; }
command -v unzip >/dev/null || { echo "Falta 'unzip' (apt install unzip)."; exit 1; }

if [ -n "$ORIGEM" ]; then
  if [ -d "$ORIGEM" ]; then ZIP="$(ls -t "$ORIGEM"/*.zip 2>/dev/null | head -n1)"; else ZIP="$ORIGEM"; fi
  [ -f "$ZIP" ] || { echo "Sem .zip em $ORIGEM"; exit 1; }
  cp "$ZIP" "$TMP/" ; ZIP="$TMP/$(basename "$ZIP")"
else
  command -v rclone >/dev/null || { echo "Falta o rclone."; exit 1; }
  echo "A obter o último backup de $REMOTE (decifra automaticamente)..."
  NOME="$(rclone lsf "${REMOTE}diario" --files-only 2>/dev/null | sort -r | head -n1)"
  [ -n "$NOME" ] || { echo "Não consegui listar ${REMOTE}diario (chave/remoto errados?)."; exit 1; }
  rclone copy "${REMOTE}diario/$NOME" "$TMP" || { echo "Falhou o download."; exit 1; }
  ZIP="$TMP/$NOME"
fi
echo "Backup: $(basename "$ZIP") ($(du -h "$ZIP" | cut -f1))"

mkdir -p "$TMP/data"
unzip -q "$ZIP" -d "$TMP/data" || { echo "Zip inválido."; exit 1; }
[ -f "$TMP/data/data.db" ] || { echo "O zip não tem data.db - backup inválido."; exit 1; }
echo "Descompactado. Ficheiros em storage: $(find "$TMP/data/storage" -type f 2>/dev/null | wc -l)"

IMG="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^gookie:' | head -n1)"
[ -n "$IMG" ] || { echo "Não encontrei a imagem gookie (corre 'bash gookie.sh instalar' primeiro)."; exit 1; }
docker run -d --name gookie-restauro -p "127.0.0.1:$PORTA:8090" -e TURNKEY_DEV=0 \
  --user "$(id -u):$(id -g)" -v "$TMP/data:/pb/pb_data" "$IMG" >/dev/null

OK=0
for _ in $(seq 1 45); do
  sleep 1
  if curl -fsS "http://127.0.0.1:$PORTA/api/health" >/dev/null 2>&1; then OK=1; break; fi
done
DUR=$(( $(date +%s) - INICIO ))
if [ "$OK" = 1 ]; then
  echo "RESTAURO OK em ${DUR} s. Regista a data e o tempo."; exit 0
fi
echo "RESTAURO FALHOU: o servidor não arrancou com o backup."; docker logs --tail 30 gookie-restauro; exit 1
