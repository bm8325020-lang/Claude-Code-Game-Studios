#!/bin/bash
# Rebaixa as versões grátis da Atomic Realm para assets/catalogo/atomic (fora do git: a licença proíbe redistribuir).
# Rodar da pasta jogo/. Usa o download grátis do itch.io (pague-o-quanto-quiser, $0).
set -e
DEST=assets/catalogo/atomic
J=$(mktemp)
baixa() { P=$1; ID=$2; OUT=$3
  curl -sSL -c $J -b $J "$P" -o $J.p; CSRF=$(grep -o 'name="csrf_token" value="[^"]*"' $J.p | head -1 | sed 's/.*value="//;s/"//')
  U=$(curl -sSL -c $J -b $J -X POST "$P/download_url" --data-urlencode "csrf_token=$CSRF" | python3 -c "import json,sys;print(json.load(sys.stdin)['url'])")
  curl -sSL -c $J -b $J "$U" -o $J.d; CSRF=$(grep -o 'name="csrf_token" value="[^"]*"' $J.d | head -1 | sed 's/.*value="//;s/"//')
  FU=$(curl -sSL -c $J -b $J -X POST "$P/file/$ID?source=game_download&after_download_lightbox=1" --data-urlencode "csrf_token=$CSRF" | python3 -c "import json,sys;print(json.load(sys.stdin)['url'])")
  curl -sSL -o "$OUT" "$FU"; }
extrai() { python3 - "$1" "$2" <<'PY'
import zipfile, sys, os
z = zipfile.ZipFile(sys.argv[1]); dest = sys.argv[2]
glt = [n for n in z.namelist() if n.lower().endswith(('.glb', '.gltf'))]
pastas = set(os.path.dirname(n) for n in glt)
for n in z.namelist():
    if not n.endswith('/') and os.path.dirname(n) in pastas and n.lower().endswith(('.glb', '.gltf', '.bin', '.png', '.jpg')):
        alvo = os.path.join(dest, n.split('/', 1)[1] if '/' in n else n)
        os.makedirs(os.path.dirname(alvo), exist_ok=True); open(alvo, 'wb').write(z.read(n))
PY
rm -f "$1"; }
W=https://atomicrealm.itch.io/post-apocalyptic-world; I=https://atomicrealm.itch.io/post-apocalyptic-interiors
for par in "$W 13070065 posto" "$W 13070064 farmacia" "$W 16082535 interiores" "$W 13070062 natureza" "$W 11128538 inicial" \
           "$I 11068038 interior_generico" "$I 16082397 escritorio"; do set -- $par; baixa $1 $2 a.zip; extrai a.zip $DEST/$3; done
echo pronto
