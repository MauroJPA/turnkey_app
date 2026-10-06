#!/usr/bin/env bash
# Teste de restauro (fazer todos os meses): descarrega e DECIFRA o backup mais
# recente da nuvem (ou usa um ficheiro/USB), descompacta numa pasta temporária,
# arranca um contentor descartável do gc_turnkey nessa pasta e confirma que responde.
# Não toca na produção.
#
#   bash backup/teste-restauro.sh                        # a partir da nuvem
#   bash backup/teste-restauro.sh /mnt/gc_turnkey-usb/gc_turnkey_backups   # pasta com .zip
#   bash backup/teste-restauro.sh /caminho/backup.zip
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
REMOTE="${REMOTE:-gc_turnkey-crypt:}"
PORTA="${PORTA:-18090}"
ORIGEM="${1:-}"
INICIO=$(date +%s)
TMP="$(mktemp -d /tmp/gc_turnkey-restauro.XXXXXX)"
trap 'docker rm -f gc_turnkey-restauro >/dev/null 2>&1; rm -rf "$TMP"' EXIT

# Estado para a app (Configurações -> Estado dos backups): data/backup_restauro.json
ESTADO="$RAIZ/data/backup_restauro.json"
NOMEZIP=""
estado() {  # estado true|false "mensagem"
  local msg; msg="$(printf '%s' "$2" | tr -d '"\\\r\n' | cut -c1-250)"
  mkdir -p "$RAIZ/data" 2>/dev/null || return 0
  printf '{"ok":%s,"quando":"%s","ficheiro":"%s","segundos":%s,"mensagem":"%s"}\n' \
    "$1" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$NOMEZIP" "$(( $(date +%s) - INICIO ))" "$msg" > "$ESTADO.tmp" 2>/dev/null \
    && mv -f "$ESTADO.tmp" "$ESTADO" 2>/dev/null || true
}
falhar() { echo "$1"; estado false "$1"; exit 1; }

command -v docker >/dev/null || falhar "Falta o Docker."
command -v unzip >/dev/null || falhar "Falta unzip (apt install unzip)."

if [ -n "$ORIGEM" ]; then
  if [ -d "$ORIGEM" ]; then ZIP="$(ls -t "$ORIGEM"/*.zip 2>/dev/null | head -n1)"; else ZIP="$ORIGEM"; fi
  [ -f "$ZIP" ] || falhar "Sem .zip em $ORIGEM"
  cp "$ZIP" "$TMP/" ; ZIP="$TMP/$(basename "$ZIP")"
else
  command -v rclone >/dev/null || falhar "Falta o rclone."
  echo "A obter o último backup de $REMOTE (decifra automaticamente)..."
  NOME="$(rclone lsf "${REMOTE}diario" --files-only 2>/dev/null | sort -r | head -n1)"
  [ -n "$NOME" ] || falhar "Não consegui listar a nuvem (chave/remoto errados?)."
  rclone copy "${REMOTE}diario/$NOME" "$TMP" || falhar "Falhou o download do backup."
  ZIP="$TMP/$NOME"
fi
NOMEZIP="$(basename "$ZIP")"
echo "Backup: $(basename "$ZIP") ($(du -h "$ZIP" | cut -f1))"

mkdir -p "$TMP/data"
unzip -q "$ZIP" -d "$TMP/data" || falhar "O zip está estragado."
[ -f "$TMP/data/data.db" ] || falhar "O zip não tem data.db - backup inválido."
echo "Descompactado. Ficheiros em storage: $(find "$TMP/data/storage" -type f 2>/dev/null | wc -l)"

IMG="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^gc_turnkey:' | head -n1)"
[ -n "$IMG" ] || falhar "Não encontrei a imagem gc_turnkey."
docker run -d --name gc_turnkey-restauro -p "127.0.0.1:$PORTA:8090" -e GC_TURNKEY_DEV=0 \
  --user "$(id -u):$(id -g)" -v "$TMP/data:/pb/pb_data" "$IMG" >/dev/null

OK=0
for _ in $(seq 1 45); do
  sleep 1
  if curl -fsS "http://127.0.0.1:$PORTA/api/health" >/dev/null 2>&1; then OK=1; break; fi
done
DUR=$(( $(date +%s) - INICIO ))
if [ "$OK" = 1 ]; then
  echo "RESTAURO OK em ${DUR} s. Regista a data e o tempo."; estado true "Restauro ok em ${DUR} s."; exit 0
fi
docker logs --tail 30 gc_turnkey-restauro
falhar "O servidor não arrancou com o backup."
