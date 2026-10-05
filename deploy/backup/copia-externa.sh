#!/usr/bin/env bash
# Copia o backup mais recente do PocketBase para a nuvem (Google Drive), CIFRADO
# antes de sair do servidor (rclone "crypt"). Corre todas as noites (agendado por
# instalar-agendamento.sh). Retenção: 30 dias em "diario/" + 12 meses em "mensal/"
# (dia 1 de cada mês).
#
#   bash backup/copia-externa.sh                     # usa o remoto "gc_turnkey-crypt:"
#   REMOTE=outro: bash backup/copia-externa.sh       # outro remoto rclone
#
# Alerta por email (opcional) se falhar: BACKUP_ALERT_TO, BACKUP_SMTP_HOST,
# BACKUP_SMTP_PORT, BACKUP_SMTP_USER, BACKUP_SMTP_PASS em .env.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
REMOTE="${REMOTE:-gc_turnkey-crypt:}"
DIAS_DIARIOS="${DIAS_DIARIOS:-30}"
MESES_MENSAIS="${MESES_MENSAIS:-12}"
IDADE_MAX_HORAS="${IDADE_MAX_HORAS:-30}"
PASTA="$RAIZ/data/backups"
LOGS="$AQUI/logs"; mkdir -p "$LOGS"
LOG="$LOGS/copia-externa.log"

log() { local l; l="$(date '+%F %T') [${2:-INFO}] $1"; echo "$l" | tee -a "$LOG"; }

# Estado para a app (Configurações -> Estado dos backups): data/backup_externo.json
ESTADO="$RAIZ/data/backup_externo.json"
estado() {  # estado true|false "ficheiro" "mensagem"
  local msg; msg="$(printf '%s' "$3" | tr -d '"\\\r\n' | cut -c1-250)"
  mkdir -p "$RAIZ/data" 2>/dev/null || return 0
  printf '{"ok":%s,"quando":"%s","ficheiro":"%s","mensagem":"%s"}\n' \
    "$1" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$2" "$msg" > "$ESTADO.tmp" 2>/dev/null \
    && mv -f "$ESTADO.tmp" "$ESTADO" 2>/dev/null || true
}

carregar_env() {
  [ -f "$RAIZ/.env" ] || return 0
  set -a; # shellcheck disable=SC1091
  . <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$RAIZ/.env"); set +a
}

alertar() {  # alertar "assunto" "corpo"
  carregar_env
  if [ -z "${BACKUP_ALERT_TO:-}" ] || [ -z "${BACKUP_SMTP_HOST:-}" ]; then
    log "Sem BACKUP_ALERT_TO/BACKUP_SMTP_HOST em .env - alerta por email não enviado." AVISO; return 0
  fi
  local msg; msg=$(printf 'From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s\r\n' \
    "${BACKUP_SMTP_USER:-gc_turnkey}" "$BACKUP_ALERT_TO" "$1" "$2")
  if printf '%s' "$msg" | curl -sS --ssl-reqd --url "smtp://${BACKUP_SMTP_HOST}:${BACKUP_SMTP_PORT:-587}" \
      --user "${BACKUP_SMTP_USER:-}:${BACKUP_SMTP_PASS:-}" --mail-from "${BACKUP_SMTP_USER:-gc_turnkey@localhost}" \
      --mail-rcpt "$BACKUP_ALERT_TO" -T - >/dev/null 2>&1; then
    log "Alerta enviado para $BACKUP_ALERT_TO."
  else
    log "Falhou o envio do alerta por email." ERRO
  fi
}

falhar() { log "$1" ERRO; estado false "${NOME:-}" "$1"; alertar "[gc_turnkey] FALHA no backup externo" "$1 -- ver $LOG"; exit 1; }

command -v rclone >/dev/null 2>&1 || falhar "rclone não está instalado (apt install rclone, ou https://rclone.org/install/)."
[ -d "$PASTA" ] || falhar "Pasta de backups não existe: $PASTA"

# 1. o backup do PocketBase de hoje existe?
ULTIMO="$(ls -t "$PASTA"/*.zip 2>/dev/null | head -n1 || true)"
[ -n "$ULTIMO" ] || falhar "Não há nenhum .zip em $PASTA (o backup noturno do PocketBase não correu?)."
IDADE_H=$(( ( $(date +%s) - $(stat -c %Y "$ULTIMO") ) / 3600 ))
[ "$IDADE_H" -le "$IDADE_MAX_HORAS" ] || falhar "O backup mais recente ($(basename "$ULTIMO")) tem ${IDADE_H} h - o backup automático do PocketBase falhou."
NOME="$(basename "$ULTIMO")"
log "Backup a enviar: $NOME ($(du -h "$ULTIMO" | cut -f1))"

# 2. enviar (cifrado pelo remoto crypt) e confirmar
rclone copy "$ULTIMO" "${REMOTE}diario" --checksum >/dev/null || falhar "rclone copy (diario) falhou."
rclone lsf "${REMOTE}diario" --files-only 2>/dev/null | grep -qx "$NOME" \
  || falhar "O ficheiro $NOME não aparece no destino depois de enviado."
log "Enviado e confirmado em ${REMOTE}diario/."

if [ "$(date +%d)" = "01" ]; then
  rclone copy "$ULTIMO" "${REMOTE}mensal" --checksum >/dev/null || falhar "rclone copy (mensal) falhou."
  log "Cópia mensal guardada em ${REMOTE}mensal/."
fi

# 3. retenção
rclone delete "${REMOTE}diario" --min-age "${DIAS_DIARIOS}d" >/dev/null 2>&1 || log "Limpeza dos diários falhou - não bloqueia." AVISO
rclone delete "${REMOTE}mensal" --min-age "$((MESES_MENSAIS * 31))d" >/dev/null 2>&1 || log "Limpeza dos mensais falhou - não bloqueia." AVISO

estado true "$NOME" "Enviado e confirmado."
log "Concluído."
