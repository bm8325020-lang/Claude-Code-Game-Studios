#!/usr/bin/env bash
# Publica o servidor: exporta o pacote (servidor.pck) e envia para a branch servidor-build (só ela, reescrita
# a cada publicação para não acumular binário no histórico). O servidor na nuvem pega sozinho em até 2 min.
# Rodar da pasta jogo/: bash tools/servidor/publica.sh [ip_do_servidor]
# Sem IP, mantém a lista de servidores que já está publicada.
set -euo pipefail
G=${GODOT:-godot}
TMP=$(mktemp -d)
"$G" --headless --path . --export-pack "Android" "$TMP/servidor.pck"
sha256sum "$TMP/servidor.pck" | cut -d' ' -f1 > "$TMP/versao.txt"
VERSAO=$(grep -oP 'const VERSAO: int = \K[0-9]+' scripts/rede.gd)
RAMO=https://raw.githubusercontent.com/bm8325020-lang/Claude-Code-Game-Studios/servidor-build
if [ $# -ge 1 ]; then
	printf '{"versao": %s, "servidores": [{"nome": "Servidor 1 (Brasil)", "ip": "%s"}]}\n' "$VERSAO" "$1" > "$TMP/servidores.json"
else
	curl -sSf "$RAMO/servidores.json" -o "$TMP/servidores.json" 2>/dev/null || echo '{"versao": '"$VERSAO"', "servidores": []}' > "$TMP/servidores.json"
	python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));d['versao']=int(sys.argv[2]);json.dump(d,open(p,'w'))" "$TMP/servidores.json" "$VERSAO"
fi
cp tools/servidor/instalar.sh "$TMP/"
ORIGEM=$(git remote get-url origin)
cd "$TMP"
git init -q -b servidor-build
git add -A
git -c user.name="servidor" -c user.email="servidor@localhost" commit -qm "servidor $(cut -c1-12 versao.txt)"
git push -qf "$ORIGEM" servidor-build
echo "publicado: $(cat versao.txt)"
rm -rf "${TMP:?}"
