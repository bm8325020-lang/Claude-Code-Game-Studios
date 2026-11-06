"""Gera as vozes da história (06/11) com Kokoro TTS (Apache-2.0, roda local) a partir de tools/voz/falas.json.
Uso: python3 -I tools/voz/gera.py <pasta com kokoro-v1.0.onnx e voices-v1.0.bin> [--refaz]
Saída: assets/voz/<id>.ogg (mono, 22 kHz, Vorbis ~48 kbps: leve para o celular). Pula o que já existe.
(ElevenLabs bloqueou a conta grátis em 06/11; o jogo só precisa do .ogg com o nome = Voz.chave(texto).)"""
import json, os, re, subprocess, sys, tempfile

import soundfile as sf
from kokoro_onnx import Kokoro

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# quem -> (voz do Kokoro, velocidade, semitons): 3 vozes pt-BR viram 7 personagens mudando ritmo e tom
ELENCO = {
    "dana": ("pf_dora", 1.05, 0.0),
    "mia": ("pf_dora", 0.9, 2.0),
    "okafor": ("pf_dora", 0.93, -2.0),
    "narrador": ("pm_santa", 0.9, -1.5),
    "tommy": ("pm_alex", 1.12, 1.0),
    "wade": ("pm_santa", 0.95, -3.5),
    "militar": ("pm_alex", 1.0, -1.0),
}


def limpa(t):
    t = t.strip().strip('"').replace('\\"', "")
    t = t.replace("WSB", "W S B").replace("Dra.", "Doutora").replace("—", ",").replace("'", "")
    t = re.sub(r"\b([A-ZÀ-Ú]{3,})\b", lambda m: m.group(1).lower(), t)  # MAIÚSCULA de destaque: lê normal
    return t


def main():
    pasta = sys.argv[1]
    refaz = "--refaz" in sys.argv
    k = Kokoro(os.path.join(pasta, "kokoro-v1.0.onnx"), os.path.join(pasta, "voices-v1.0.bin"))
    falas = json.load(open(os.path.join(RAIZ, "tools/voz/falas.json")))
    saida = os.path.join(RAIZ, "assets/voz")
    os.makedirs(saida, exist_ok=True)
    feitas = 0
    for f in falas:
        dest = os.path.join(saida, f["id"] + ".ogg")
        if os.path.exists(dest) and not refaz:
            continue
        voz, vel, semi = ELENCO.get(f["voz"], ELENCO["narrador"])
        audio, sr = k.create(limpa(f["texto"]), voice=voz, speed=vel, lang="pt-br")
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            sf.write(tmp.name, audio, sr)
            r = 2 ** (semi / 12.0)
            filtro = "asetrate=%d,aresample=%d,atempo=%.4f," % (int(sr * r), sr, 1.0 / r) if semi else ""
            filtro += "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-af", filtro, "-ac", "1", "-ar", "22050",
                            "-c:a", "libvorbis", "-q:a", "1", dest], check=True)
        feitas += 1
    print("vozes novas:", feitas, "de", len(falas))


if __name__ == "__main__":
    main()
