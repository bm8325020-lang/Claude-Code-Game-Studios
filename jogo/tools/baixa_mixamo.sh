#!/usr/bin/env bash
# Baixa as animações do Mixamo da pasta do Drive do dono do jogo para assets/mixamo/ (fora do git: a licença
# do Mixamo não deixa redistribuir os arquivos brutos). Rodar da pasta jogo/: bash tools/baixa_mixamo.sh
set -euo pipefail
PASTA_DRIVE=1EQ2MRCHkkmERJMBE78ROoYbRpnQAfjyW
TMP=$(mktemp -d)
A=assets/mixamo
mkdir -p "$A"/{aventura,zumbi,rifle,pistola,machado,zumbi2,soltas}
curl -sSL "https://drive.google.com/embeddedfolderview?id=$PASTA_DRIVE" -o "$TMP/pasta.html"
python3 -I - "$TMP/pasta.html" > "$TMP/lista.tsv" <<'PY'
import re, html, sys
s = open(sys.argv[1]).read()
for m in re.finditer(r'file/d/([A-Za-z0-9_-]+).*?flip-entry-title">([^<]*)', s, re.S):
    print(m.group(1) + "\t" + html.unescape(m.group(2)))
PY
while IFS=$'\t' read -r id nome; do
	curl -sSL -o "$TMP/$nome" "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
done < "$TMP/lista.tsv"
unzip -qo "$TMP/Action Adventure Pack.zip" -d "$A/aventura"
unzip -qo "$TMP/Scary Zombie Pack.zip" -d "$A/zumbi"
unzip -qo "$TMP/Basic Shooter Pack.zip" -d "$A/rifle"
unzip -qo "$TMP/Pistol_Handgun Locomotion Pack.zip" -d "$A/pistola"
unzip -qo "$TMP/Pro Melee Axe Pack.zip" -d "$A/machado"
unzip -qo "$TMP/Not So Scary Zombie Pack.zip" -d "$A/zumbi2"
cp "$TMP"/*.fbx "$A/soltas/"
mv "$A/aventura/X Bot.fbx" "$A/xbot.fbx"
rm -f "$A"/*/"X Bot.fbx"
# nomes sem espaço, maiúscula ou parênteses ("Pistol Idle.fbx" -> "pistol_idle.fbx")
for d in "$A"/*/; do
	for f in "$d"*.fbx; do
		n="$d$(basename "$f" | tr 'A-Z ' 'a-z_' | tr -d '()')"
		[ "$f" = "$n" ] || mv "$f" "$n"
	done
done
rm -rf "${TMP:?}"
echo "ok: $(find "$A" -name '*.fbx' | wc -l) arquivos em $A"
