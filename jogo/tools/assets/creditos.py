# Junta os créditos de todos os assets (CC BY pede o nome do autor dentro do jogo) em scripts/creditos.gd (Creditos.TEXTO),
# que a tela CRÉDITOS do menu mostra. Rodar depois de baixar asset novo:
#   python3 -I tools/assets/creditos.py
# Fontes: assets/mundo/LICENCAS.md (só os brutos que normaliza.py usa), assets/LICENCAS.txt e os CREDITOS.txt das pastas.
import os, re

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
A = os.path.join(RAIZ, "assets")


def le(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


usados = le(os.path.join(RAIZ, "tools", "assets", "normaliza.py"))
partes = ["DEAD DISTRICT — CRÉDITOS", "", "Modelos 3D, sons e texturas de terceiros usados no jogo. Obrigado aos autores!", ""]
linhas = []
for l in le(os.path.join(A, "mundo", "LICENCAS.md")).splitlines():
    c = [x.strip() for x in l.strip().strip("|").split("|")]
    if len(c) < 9 or not c[0].startswith("brutos/"):
        continue
    arq = c[0][len("brutos/"):]
    if arq not in usados:
        continue  # baixado mas recusado (não vai no jogo)
    url = re.sub(r"^https?://", "", c[4])
    linhas.append("• \"%s\" — %s (%s) — %s" % (c[1], c[2], c[3], url))
if linhas:
    partes += ["MUNDO (vegetação, construções)"] + linhas + [""]
for nome, titulo in (("LICENCAS.txt", "ARMAS E OBJETOS"), ("zumbis/CREDITOS.txt", "ZUMBIS"),
                     ("moveis/CREDITOS.txt", "MÓVEIS"), ("catalogo/CREDITOS.txt", "CAPITAL AO LONGE"),
                     ("sons/amb/CREDITOS.txt", "SONS"), ("sons/armas/CREDITOS.txt", "SONS DAS ARMAS")):
    p = os.path.join(A, nome)
    if os.path.exists(p):
        partes += [titulo, le(p).strip(), ""]
texto = "\n".join(partes).replace("\\", "\\\\").replace('"""', "'''")
with open(os.path.join(RAIZ, "scripts", "creditos.gd"), "w", encoding="utf-8") as f:
    f.write("# Gerado por tools/assets/creditos.py (não editar à mão).\nclass_name Creditos\n\nconst TEXTO := \"\"\"%s\"\"\"\n" % texto)
print("CREDITOS_OK", len(linhas), "modelos do mundo")
