#!/usr/bin/env bash
# Envia um pacote empacotado (scripts/empacotar-producao.ps1) para o servidor,
# confirma o SHA-256 depois da transferência e faz a atualização sozinho.
# Aborta sem mexer em nada se o hash não bater certo.
#
# Uso:
#   bash scripts/publicar-producao.sh <pacote.tar.gz> <utilizador@servidor> [pasta-no-servidor] [porta-ssh]
#
# Exemplo:
#   bash scripts/publicar-producao.sh dist/gc_turnkey-servidor-1.27.0.tar.gz ana@virusserver /opt/gc_turnkey 2022
#
# Pasta-no-servidor por omissão: /opt/gc_turnkey · Porta SSH por omissão: 22
set -euo pipefail

USO="Uso: bash scripts/publicar-producao.sh <pacote.tar.gz> <utilizador@servidor> [pasta-no-servidor] [porta-ssh]"
PACOTE="${1:?$USO}"
SERVIDOR="${2:?$USO}"
APP_DIR="${3:-/opt/gc_turnkey}"
PORTA="${4:-22}"

[ -f "$PACOTE" ] || { echo "Não encontrei o pacote: $PACOTE" >&2; exit 1; }

NOME_PACOTE="$(basename "$PACOTE")"
HASH_LOCAL="$(sha256sum "$PACOTE" | awk '{print $1}')"

echo "== Pacote: $NOME_PACOTE"
echo "== SHA-256 (calculado agora, antes de enviar): $HASH_LOCAL"
echo "== Servidor: $SERVIDOR (porta $PORTA)"
echo

echo "== A enviar para $SERVIDOR:/tmp/ ..."
scp -P "$PORTA" "$PACOTE" "$SERVIDOR:/tmp/$NOME_PACOTE"
echo

echo "== A confirmar o hash e a atualizar no servidor ..."
ssh -p "$PORTA" "$SERVIDOR" bash -s -- "$NOME_PACOTE" "$HASH_LOCAL" "$APP_DIR" <<'REMOTO'
set -euo pipefail
PACOTE="/tmp/$1"
HASH_ESPERADO="$2"
APP_DIR="$3"

HASH_OBTIDO="$(sha256sum "$PACOTE" | awk '{print $1}')"
if [ "$HASH_OBTIDO" != "$HASH_ESPERADO" ]; then
  echo "ERRO: o SHA-256 do ficheiro no servidor não bate certo com o que foi enviado." >&2
  echo "  esperado: $HASH_ESPERADO" >&2
  echo "  obtido:   $HASH_OBTIDO" >&2
  echo "Nada foi tocado — o ficheiro pode ter corrompido na transferência. Tenta enviar outra vez." >&2
  exit 1
fi
echo "SHA-256 confirmado — o ficheiro chegou intacto."
echo

cd "$APP_DIR"

echo "-- Backup antes de mexer"
bash gc_turnkey.sh backup-agora

echo "-- A tirar os ficheiros antigos da app (data/ e .env ficam)"
rm -rf web hooks migrations

echo "-- A extrair o pacote novo"
tar -xzf "$PACOTE" -C "$APP_DIR"

echo "-- A atualizar (reconstrói a imagem e reinicia; migrations aplicam-se sozinhas)"
bash gc_turnkey.sh atualizar

echo "-- A esperar que o servidor responda (até 60 s)"
PORTA_APP="$(grep -E '^GC_TURNKEY_PORTA=' .env 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
PORTA_APP="${PORTA_APP:-8091}"
for _ in $(seq 1 30); do
  curl -fsS "http://127.0.0.1:${PORTA_APP}/api/health" >/dev/null 2>&1 && break
  sleep 2
done

echo "-- Estado"
bash gc_turnkey.sh estado || echo "AVISO: o servidor ainda não respondeu — vê 'bash gc_turnkey.sh logs'." >&2

rm -f "$PACOTE"
echo
echo "Atualização concluída. Faz o ensaio rápido: login, uma lista, uma produção."
REMOTO
