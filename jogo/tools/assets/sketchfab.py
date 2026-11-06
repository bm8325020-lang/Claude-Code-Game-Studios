# Baixa modelos do Sketchfab (só licença que permite uso comercial) para assets/mundo/brutos/<pasta>/ (sem import no Godot: .gdignore; o normaliza.py tira a versão do jogo) e registra em
# assets/mundo/LICENCAS.md. O token fica fora do repositório (/root/.sketchfab_token).
#   python3 -I tools/assets/sketchfab.py <pasta> <uid> [uid...]        (ex.: vegetation/trees)
#   python3 -I tools/assets/sketchfab.py --info <uid> [uid...]           (só mostra tamanho e licença)
import json, os, re, sys, time, urllib.error, urllib.request

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "mundo")
LIC = os.path.join(RAIZ, "LICENCAS.md")
TOK = open("/root/.sketchfab_token").read().strip()
OK_LIC = ("CC Attribution", "CC0", "Free Standard", "Public Domain")


def api(caminho):
    req = urllib.request.Request("https://api.sketchfab.com/v3/" + caminho, headers={"Authorization": "Token " + TOK, "User-Agent": "DeadDistrict-tools/1.0"})
    for k in range(6):  # o Sketchfab limita requisições (429): espera e tenta de novo
        try:
            time.sleep(2.0)
            return json.load(urllib.request.urlopen(req, timeout=60))
        except urllib.error.HTTPError as e:
            if e.code != 429 or k == 5:
                raise
            time.sleep(20 * (k + 1))


def nome_arq(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")[:48] or "modelo"


def info(uid):
    m = api("models/" + uid)
    lic = m.get("license", {}).get("label", "?")
    return m, lic, lic.startswith(OK_LIC) and "NonCommercial" not in lic and "NoDerivs" not in lic


def baixa(pasta, uid):
    m, lic, ok = info(uid)
    if not ok:
        print("PULA (licença)", uid, lic)
        return
    d = api("models/%s/download" % uid)
    if "glb" not in d:
        print("PULA (sem glb)", uid)
        return
    dest_dir = os.path.join(RAIZ, "brutos", pasta)
    os.makedirs(dest_dir, exist_ok=True)
    arq = nome_arq(m["name"]) + ".glb"
    dest = os.path.join(dest_dir, arq)
    urllib.request.urlretrieve(d["glb"]["url"], dest)
    mb = os.path.getsize(dest) / 1e6
    linha = "| brutos/%s/%s | %s | %s | %s | %s | %.1f MB | %d | sim | %s |\n" % (
        pasta, arq, m["name"].replace("|", "/"), m["user"]["displayName"].replace("|", "/"), lic,
        m["viewerUrl"], mb, m.get("faceCount", 0), "obrigatória" if "Attribution" in lic else "não")
    with open(LIC, "a") as f:
        f.write(linha)
    print("OK", pasta + "/" + arq, "%.1f MB" % mb, m.get("faceCount"), lic)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "--busca":  # --busca "termo" [máx. de faces]: só baixáveis com licença comercial, os mais leves primeiro
        import urllib.parse
        lim = int(a[2]) if len(a) > 2 else 20000
        r = api("search?type=models&downloadable=true&count=24&q=" + urllib.parse.quote(a[1]))
        for m in sorted(r.get("results", []), key=lambda m: m.get("faceCount", 0)):
            lic = (m.get("license") or {}).get("label", "?")
            if m.get("faceCount", 0) <= lim and lic.startswith(OK_LIC) and "NonCommercial" not in lic and "NoDerivs" not in lic:
                print(m["uid"], m.get("faceCount"), lic, "|", m["name"][:60])
    elif a[0] == "--info":
        for uid in a[1:]:
            m, lic, ok = info(uid)
            d = api("models/%s/download" % uid) if ok else {}
            print(uid, "glb %.1f MB" % (d.get("glb", {}).get("size", 0) / 1e6), m.get("faceCount"), lic, "|", m["name"][:50], "| ok" if ok else "| NÃO")
    else:
        for uid in a[1:]:
            try:
                baixa(a[0], uid)
            except Exception as e:
                print("ERRO", uid, e)
