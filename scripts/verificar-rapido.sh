#!/usr/bin/env bash
# Verificação RÁPIDA para o dia a dia (segundos): análise, testes e sintaxe dos
# hooks. Não corre as migrations nem a suíte de segurança do PocketBase (isso é
# o `scripts/verificar.sh`, só no fim de um lote e antes de publicar).
#
#   bash scripts/verificar-rapido.sh                  # analyze + todos os testes
#   bash scripts/verificar-rapido.sh test/etiqueta_test.dart test/ponto_test.dart
#                                                     # analyze + só estes testes
set -u
cd "$(dirname "$0")/.."
falhou=0
ok() { echo "  OK  $1"; }
mau() { echo " FALHA $1"; falhou=1; }

echo "== flutter analyze"
flutter analyze >/tmp/vr_analyze.log 2>&1 && ok "analyze limpo" || { grep -E "^\s+(info|warning|error)" /tmp/vr_analyze.log | head -20; mau "analyze"; }

echo "== flutter test ${*:-(todos)}"
flutter test "$@" >/tmp/vr_test.log 2>&1 && ok "testes verdes" || { tail -30 /tmp/vr_test.log; mau "testes"; }

if command -v node >/dev/null 2>&1; then
  echo "== hooks (node --check) e testes de node"
  for f in pb/hooks/*.js; do node --check "$f" >/dev/null 2>&1 || mau "sintaxe $f"; done
  for t in test/seguranca/test_*.js; do node "$t" >/tmp/vr_node.log 2>&1 || { tail -10 /tmp/vr_node.log; mau "$t"; }; done
  [ "$falhou" -eq 0 ] && ok "hooks e testes de node"
fi

echo
[ "$falhou" -eq 0 ] && echo "RÁPIDO OK (falta o scripts/verificar.sh completo antes de publicar)." || echo "HÁ FALHAS."
exit "$falhou"
