# Equipe de IAs pelo OmniRoute (dono, 05/11: "você é o chefe; o que não precisa de você manda para as outras IAs").
# Endereço e chave só no ambiente (nunca em arquivo do repositório):
#   export OMNI_URL=https://.../v1 OMNI_KEY=...
#   python3 tools/ia/equipe.py modelos                       # lista os modelos ligados
#   python3 tools/ia/equipe.py manda tarefas.json saida_dir  # [{"titulo","pedido","arquivos":[...]}] -> um modelo por tarefa
# Cada tarefa vai para um modelo (em rodízio, em paralelo); a resposta vira saida_dir/<n>_<titulo>.md (o relatório).
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

URL = os.environ.get("OMNI_URL", "").rstrip("/")
KEY = os.environ.get("OMNI_KEY", "")
# o OmniRoute do dono tem centenas de modelos (imagem, vídeo...): a equipe são os "auto/" de código e raciocínio
EQUIPE = os.environ.get("OMNI_EQUIPE", "auto/best-coding,auto/pro-coding,auto/coding:reliable,auto/best-reasoning,"
                        "auto/smart,auto/coding,auto/best-chat").split(",")
SISTEMA = ("Você trabalha num jogo de zumbi em Godot 4.7 (GDScript). Responda em português. Faça só o que foi pedido. "
           "Para mudança de código, devolva o arquivo inteiro ou um diff unificado, e no fim um RELATÓRIO curto: o que fez, "
           "o que não fez e riscos.")


def chama(caminho, corpo=None, tempo=600):
    req = urllib.request.Request(URL + caminho, data=json.dumps(corpo).encode() if corpo else None,
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                          "bypass-tunnel-reminder": "1"})  # túnel loca.lt (OmniRoute no celular)
    with urllib.request.urlopen(req, timeout=tempo) as r:
        return json.load(r)


def conversa(modelo, mensagens, tempo=900):
    """Resposta em pedaços (stream): o túnel do celular derruba conexão parada esperando resposta longa."""
    corpo = {"model": modelo, "messages": mensagens, "stream": True}
    req = urllib.request.Request(URL + "/chat/completions", data=json.dumps(corpo).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                          "bypass-tunnel-reminder": "1"})
    partes = []
    with urllib.request.urlopen(req, timeout=tempo) as r:
        for linha in r:
            linha = linha.decode("utf-8", "replace").strip()
            if not linha.startswith("data:") or linha.endswith("[DONE]"):
                continue
            try:
                d = json.loads(linha[5:])
                partes.append((d["choices"][0].get("delta") or {}).get("content") or "")
            except (ValueError, KeyError, IndexError):
                pass
    return "".join(partes)


def modelos():
    return [m["id"] for m in chama("/models").get("data", [])]


def faz(args):
    n, tarefa, modelo, saida = args
    texto = tarefa["pedido"]
    for arq in tarefa.get("arquivos", []):
        texto += "\n\n=== %s ===\n%s" % (arq, open(arq, encoding="utf-8").read())
    for tentativa in range(3):  # túnel do celular cai de vez em quando (502/408)
        try:
            resposta = conversa(modelo, [{"role": "system", "content": SISTEMA}, {"role": "user", "content": texto}])
            if resposta.strip():
                break
            resposta = "ERRO: resposta vazia"
        except Exception as e:  # um modelo fora do ar não derruba os outros
            resposta = "ERRO: %s" % e
    nome = os.path.join(saida, "%02d_%s.md" % (n, "".join(c if c.isalnum() else "_" for c in tarefa["titulo"])[:40]))
    open(nome, "w", encoding="utf-8").write("# %s\nmodelo: %s\n\n%s\n" % (tarefa["titulo"], modelo, resposta))
    return nome, modelo, resposta.startswith("ERRO")


if __name__ == "__main__":
    if not URL or not KEY:
        sys.exit("faltam OMNI_URL e OMNI_KEY no ambiente")
    if sys.argv[1] == "modelos":
        print("\n".join(modelos()))
    elif sys.argv[1] == "manda":
        tarefas = json.load(open(sys.argv[2], encoding="utf-8"))
        os.makedirs(sys.argv[3], exist_ok=True)
        ms = EQUIPE
        with ThreadPoolExecutor(len(ms)) as ex:
            for nome, modelo, erro in ex.map(faz, [(k, t, ms[k % len(ms)], sys.argv[3]) for k, t in enumerate(tarefas)]):
                print(("ERRO " if erro else "ok   ") + modelo + " -> " + nome)
