#!/bin/bash
# Regera o mapa inteiro: modelos (Blender) -> import -> medidas -> planta (Raven Creek) -> malha de navegação -> testes.
#   bash tools/pipeline_mapa.sh [sem_modelos] > log   (resumo dos testes em $SAIDA/testes.txt; fim = PIPE_FIM)
cd "$(dirname "$0")/.."
G=${G:-/home/user/.local/godot/Godot_v4.7.2-stable_linux.x86_64}
B=${B:-$HOME/.local/blender/blender}
SAIDA=${SAIDA:-/tmp}
if [ "$1" != "sem_modelos" ]; then
  $B -b -P tools/blender/ruinas.py -- assets/ruinas 2>&1 | grep -E "Error|Traceback|RUINAS_OK"
  $B -b -P tools/blender/cidade.py -- assets/ruinas 2>&1 | grep -E "Error|Traceback|CIDADE_OK"
  $B -b -P tools/blender/casas_us.py -- assets/ruinas 2>&1 | grep -E "Error|Traceback|INTERIOR_PROBLEMA|CASAS_US_OK"
  timeout 900 $G --headless --path . --import > /dev/null 2>&1
  timeout 300 $G --headless --path . -s res://tools/mapa/mede_ruinas.gd 2>&1 | grep -i "script error"
fi
python3 -I tools/mapa/raven_creek.py assets/mapa/cidade.json && python3 -I tools/mapa/minimapa.py && echo PLANTA_OK
echo "== nav"; timeout 3600 $G --headless --path . -s res://tools/assa_navegacao.gd -- salva_nav 2>&1 | grep -E "NAV salva|SCRIPT ERROR"
echo "== testes"; : > $SAIDA/testes.txt
for f in tests/test_*.gd; do
  t=$(basename $f .gd)
  case $t in test_rede|test_dedicado|test_busca|test_pvp|test_sala_sobrev) continue;; esac
  r=$(timeout 500 $G --headless --path . --fixed-fps 60 -s res://tests/$t.gd 2>&1 | grep -E "PASS|FAIL|^FALHA|SCRIPT ERROR" | tail -6 | tr '\n' ' ')
  echo "$t: ${r:-SEM RESULTADO}" >> $SAIDA/testes.txt
done
(timeout 150 $G --headless --path . -s res://tests/test_rede.gd -- servidor > $SAIDA/srv.log 2>&1 &); sleep 2
r=$(timeout 150 $G --headless --path . -s res://tests/test_rede.gd -- cliente 2>&1 | grep -E "REDE" | tr '\n' ' ')
echo "test_rede: $r $(grep REDE $SAIDA/srv.log)" >> $SAIDA/testes.txt
echo PIPE_FIM
