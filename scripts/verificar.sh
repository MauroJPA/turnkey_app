#!/usr/bin/env bash
# Verificação antes de juntar código: análise, testes, sintaxe dos hooks e
# migrations numa base de dados vazia. Correr na raiz do projeto:
#   bash scripts/verificar.sh
set -u
cd "$(dirname "$0")/.."
falhou=0
ok() { echo "  OK  $1"; }
mau() { echo " FALHA $1"; falhou=1; }

echo "== flutter analyze"
flutter analyze >/tmp/verif_analyze.log 2>&1 && ok "analyze limpo" || { cat /tmp/verif_analyze.log; mau "analyze"; }

echo "== flutter test"
flutter test >/tmp/verif_test.log 2>&1 && ok "testes verdes" || { tail -30 /tmp/verif_test.log; mau "testes"; }

echo "== sintaxe dos hooks (node --check)"
if command -v node >/dev/null 2>&1; then
  for f in pb/hooks/*.js; do
    node --check "$f" >/dev/null 2>&1 || mau "$f"
  done
  [ "$falhou" -eq 0 ] && ok "hooks sem erros de sintaxe"
else
  echo "  (node não instalado — passo ignorado)"
fi

echo "== migrations numa base de dados vazia"
PB=pb/bin/pocketbase.exe
[ -x "$PB" ] || PB=pb/bin/pocketbase
if [ -x "$PB" ]; then
  tmp=$(mktemp -d)
  "$PB" serve --http=127.0.0.1:8199 --dir="$tmp/data" \
    --migrationsDir=pb/migrations --hooksDir=pb/hooks >"$tmp/pb.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 30); do
    curl -s http://127.0.0.1:8199/api/health >/dev/null 2>&1 && break
    sleep 1
  done
  if curl -s http://127.0.0.1:8199/api/health >/dev/null 2>&1 \
     && ! grep -qiE "error|panic" "$tmp/pb.log"; then
    ok "migrations aplicadas sem erros"
  else
    tail -20 "$tmp/pb.log"; mau "migrations"
  fi
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  rm -rf "$tmp"
else
  echo "  (PocketBase não encontrado em pb/bin — passo ignorado)"
fi

echo "== segurança (estático)"
if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
  PY=$(command -v python || command -v python3)
  PYTHONIOENCODING=utf-8 "$PY" test/security/estatico.py >/tmp/verif_seg_est.log 2>&1     && ok "segredos e ficheiros sensíveis" || { tail -15 /tmp/verif_seg_est.log; mau "segurança estática"; }
  echo "== vigia de segurança do servidor (python)"
  PYTHONIOENCODING=utf-8 "$PY" test/seguranca/test_vigia.py >/tmp/verif_vigia.log 2>&1 \
    && ok "vigia de segurança (testes)" || { tail -20 /tmp/verif_vigia.log; mau "vigia de segurança"; }
  echo "== segurança (isolamento, papéis, endpoints — servidor descartável)"
  PYTHONIOENCODING=utf-8 "$PY" test/security/seguranca.py >/tmp/verif_seg.log 2>&1     && ok "testes de segurança do PocketBase" || { grep "FALHA" /tmp/verif_seg.log | head -15; mau "segurança do PocketBase"; }
else
  echo "  (python não instalado — testes de segurança ignorados)"
fi

echo
[ "$falhou" -eq 0 ] && echo "TUDO OK — pode juntar." || echo "HÁ FALHAS — não juntar."
exit "$falhou"
