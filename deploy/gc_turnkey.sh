#!/usr/bin/env bash
# Gestão do servidor gc_turnkey (Docker Compose). Correr na pasta onde está o compose.yaml:
#   bash gc_turnkey.sh instalar            # 1.ª vez: prepara tudo e arranca
#   bash gc_turnkey.sh superutilizador you@exemplo.pt
#   bash gc_turnkey.sh estado | logs | iniciar | parar | reiniciar
#   bash gc_turnkey.sh backup-agora        # cópia completa (pára ~10 s o servidor)
#   bash gc_turnkey.sh restaurar <ficheiro>  # .tar.gz do backup-agora ou .zip do PocketBase
#   bash gc_turnkey.sh atualizar           # reconstrói e reinicia (depois de trocar os ficheiros)
set -euo pipefail
cd "$(dirname "$0")"

msg()  { printf '\033[1m%s\033[0m\n' "$*"; }
erro() { printf '\033[31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

precisa_docker() {
  command -v docker >/dev/null 2>&1 || erro "Docker não está instalado (https://docs.docker.com/engine/install/debian/)."
  docker compose version >/dev/null 2>&1 || erro "Falta o plugin 'docker compose' (apt install docker-compose-plugin)."
  docker info >/dev/null 2>&1 || erro "Sem permissão para o Docker. Usa sudo ou põe o teu utilizador no grupo 'docker'."
}

valor_env() { grep -E "^$1=" .env 2>/dev/null | tail -n1 | cut -d= -f2- || true; }

definir_env() {  # definir_env CHAVE VALOR  (acrescenta ou substitui, sem mostrar o valor)
  if grep -qE "^$1=" .env 2>/dev/null; then
    local tmp; tmp=$(mktemp)
    grep -vE "^$1=" .env > "$tmp" || true
    printf '%s=%s\n' "$1" "$2" >> "$tmp"
    cat "$tmp" > .env && rm -f "$tmp"
  else
    printf '%s=%s\n' "$1" "$2" >> .env
  fi
}

gerar_chave32() {
  local k=""
  while [ "${#k}" -lt 32 ]; do
    k="$k$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
  done
  printf '%s' "${k:0:32}"
}

porta() { local p; p=$(valor_env GC_TURNKEY_PORTA); echo "${p:-8091}"; }

porta_ocupada() {  # 0 se algo já responde nessa porta local
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

escolher_porta() {
  local p; p=$(valor_env GC_TURNKEY_PORTA)
  if [ -n "$p" ]; then
    # já escolhida numa instalação anterior: só serve se for o nosso contentor
    if porta_ocupada "$p" && ! docker ps --format '{{.Names}}' | grep -qx gc_turnkey; then
      erro "A porta $p (GC_TURNKEY_PORTA) já está ocupada por outra aplicação. Muda-a em .env."
    fi
    return 0
  fi
  p=8091
  while porta_ocupada "$p"; do p=$((p + 1)); [ "$p" -lt 8140 ] || erro "Não encontrei uma porta livre entre 8091 e 8140."; done
  definir_env GC_TURNKEY_PORTA "$p"
  msg "Porta local escolhida: $p (a 8090 e outras já em uso ficaram de fora)."
}

migrar_legado() {
  # Instalações anteriores (antes de 1.7.0) chamavam-se "gookie" e usavam TURNKEY_*/GOOKIE_* no .env.
  if [ -f .env ] && grep -qE '^(TURNKEY_|GOOKIE_)' .env; then
    local tmp; tmp=$(mktemp)
    sed -E 's/^TURNKEY_/GC_TURNKEY_/; s/^GOOKIE_/GC_TURNKEY_/' .env > "$tmp"
    cat "$tmp" > .env && rm -f "$tmp"
    msg "Migrei os nomes das variáveis do .env (TURNKEY_*/GOOKIE_* → GC_TURNKEY_*); os valores não mudaram."
  fi
  if docker ps -a --format '{{.Names}}' | grep -qx gookie; then
    msg "A remover o contentor antigo 'gookie' (os dados em ./data não são tocados) ..."
    docker rm -f gookie >/dev/null
    docker network rm gookie_default >/dev/null 2>&1 || true
  fi
}

versao_app() { [ -f VERSAO.txt ] && sed -n 's/^App: *v\([^ ]*\).*/\1/p' VERSAO.txt | head -n1 || echo local; }

cmd_instalar() {
  precisa_docker
  migrar_legado
  [ -d web ] && [ -d hooks ] && [ -d migrations ] || erro "Faltam as pastas web/hooks/migrations (descompacta o pacote completo)."
  mkdir -p data backups-manuais
  if [ ! -f .env ]; then
    cp .env.example .env
    chmod 600 .env
    msg "Criei .env a partir do exemplo."
  fi
  chmod 600 .env
  if [ "$(valor_env GC_TURNKEY_ENC_KEY | wc -c)" -lt 33 ]; then
    definir_env GC_TURNKEY_ENC_KEY "$(gerar_chave32)"
    msg "Gerei a chave de cifra (GC_TURNKEY_ENC_KEY). Ela NÃO é mostrada aqui:"
    msg "  → abre .env, copia a linha GC_TURNKEY_ENC_KEY para o gestor de palavras-passe (fora deste servidor)."
  fi
  escolher_porta
  definir_env GC_TURNKEY_UID "$(id -u)"
  definir_env GC_TURNKEY_GID "$(id -g)"
  definir_env GC_TURNKEY_VERSAO "$(versao_app)"
  if [ -z "$(valor_env GEMINI_API_KEY)" ]; then
    msg "Aviso: GEMINI_API_KEY está vazia em .env (faturas por IA não vão funcionar até a preencheres)."
  fi
  msg "A construir a imagem (1.ª vez demora 1–2 min) ..."
  docker compose build
  docker compose up -d
  msg "A aguardar o servidor (a 1.ª vez aplica as migrations, ~1 min) ..."
  for _ in $(seq 1 90); do
    if curl -fsS "http://127.0.0.1:$(porta)/api/health" >/dev/null 2>&1; then
      msg "Servidor a responder. Próximo: bash gc_turnkey.sh superutilizador o-teu-email"
      return 0
    fi
    sleep 2
  done
  docker compose logs --tail 40
  erro "O servidor não respondeu a tempo (ver os registos acima)."
}

cmd_superutilizador() {
  precisa_docker
  local email="${1:-}"
  [ -n "$email" ] || erro "Uso: bash gc_turnkey.sh superutilizador o-teu-email@exemplo.pt"
  local p1 p2
  read -r -s -p "Palavra-passe (mín. 10 caracteres, longa e única): " p1; echo
  read -r -s -p "Repete: " p2; echo
  [ "$p1" = "$p2" ] || erro "As palavras-passe não coincidem."
  [ "${#p1}" -ge 10 ] || erro "Palavra-passe demasiado curta."
  docker compose run --rm --no-deps --entrypoint /pb/pocketbase gc_turnkey \
    superuser upsert "$email" "$p1" --dir=/pb/pb_data --migrationsDir=/pb/pb_migrations
  msg "Superutilizador criado. Entra em /_/ com este email para aprovar registos."
}

cmd_backup_agora() {
  precisa_docker
  mkdir -p backups-manuais
  local f="backups-manuais/gc_turnkey-dados-$(date +%Y%m%d-%H%M%S).tar.gz"
  msg "A parar o servidor para copiar ficheiros coerentes ..."
  docker compose stop gc_turnkey
  tar -czf "$f" data
  docker compose start gc_turnkey
  msg "Feito: $f ($(du -h "$f" | cut -f1)). Guarda também o .env (segredos)."
}

cmd_restaurar() {
  precisa_docker
  local f="${1:-}"
  [ -f "$f" ] || erro "Uso: bash gc_turnkey.sh restaurar <ficheiro.tar.gz|backup.zip>"
  printf 'Isto SUBSTITUI os dados atuais (ficam guardados em data.antes-...). Continuar? [s/N] '
  read -r r; [ "$r" = "s" ] || erro "Cancelado."
  docker compose stop gc_turnkey 2>/dev/null || true
  [ -d data ] && mv data "data.antes-$(date +%Y%m%d-%H%M%S)"
  case "$f" in
    *.tar.gz|*.tgz) tar -xzf "$f" ;;
    *.zip) mkdir -p data && (command -v unzip >/dev/null 2>&1 || erro "Falta 'unzip' (apt install unzip)") && unzip -q "$f" -d data ;;
    *) erro "Formato não suportado (usa .tar.gz ou .zip)." ;;
  esac
  [ -f data/data.db ] || erro "Não encontrei data/data.db no ficheiro: backup inválido."
  docker compose up -d
  msg "Restaurado. Confirma com: bash gc_turnkey.sh estado"
}

case "${1:-ajuda}" in
  instalar)        cmd_instalar ;;
  superutilizador) shift; cmd_superutilizador "$@" ;;
  iniciar)         precisa_docker; docker compose up -d ;;
  parar)           precisa_docker; docker compose stop ;;
  reiniciar)       precisa_docker; docker compose restart ;;
  estado)          precisa_docker; docker compose ps; curl -fsS "http://127.0.0.1:$(porta)/api/health" && echo ;;
  logs)            precisa_docker; docker compose logs -f --tail 100 ;;
  backup-agora)    cmd_backup_agora ;;
  restaurar)       shift; cmd_restaurar "$@" ;;
  atualizar)       precisa_docker; migrar_legado; definir_env GC_TURNKEY_VERSAO "$(versao_app)"; docker compose build && docker compose up -d && msg "Atualizado." ;;
  *)               sed -n '2,9p' "$0" ;;
esac
