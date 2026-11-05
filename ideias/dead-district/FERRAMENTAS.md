# Ferramentas (auditoria 05/11)
Ambiente: Ubuntu 24.04 x86_64, 4 núcleos, 15 GB RAM, disco ~2,4 GB livres (APERTADO: Ghidra precisa ~1 GB).
| Ferramenta | Estado | Versão | Teste real |
|---|---|---|---|
| Java (OpenJDK) | instalado | 21.0.12 | ok |
| Node.js | instalado | 22.22.0 | ok |
| Git | instalado | 2.43.0 | ok |
| Python | instalado | 3.13 | ok |
| Claude Code | instalado | 2.1.318 | ok (subagentes via ferramenta Agent) |
| JADX | INSTALADO 05/11 (/root/.local/re/jadx) | 1.5.6 | decompilou o APK do nosso jogo (1919 .java, 80 erros normais) |
| Apktool | INSTALADO 05/11 (/root/.local/re/apktool.jar) | 3.0.3 | abriu o APK do nosso jogo (manifesto, assets) |
| REA (morluto/rea) | repositório existe (git ls-remote ok) | — | NÃO instalado: ler o README antes; sem uso até haver binário legítimo |
| Ghidra | ausente | — | adiado: só serve para binário nativo, e não temos binário legítimo dos jogos; ~1 GB |
| radare2/rizin/Cutter, Frida, binwalk, unblob | ausentes | — | adiados (mesma razão) |
| x64dbg | não se aplica | — | só Windows |
| ADB | ausente | — | só útil com o celular do dono ligado (APK instalado por ele) |
| RDEN | NÃO IDENTIFICADO | — | pedir ao dono o link do projeto |
| OmniRoute (equipe de IAs) | funcionando | — | tools/ia/equipe.py; túnel loca.lt no celular do dono |
Observação: a máquina é temporária; o que foi instalado em /root/.local some quando ela for reciclada (reinstalar daqui).

## 05/11 — RAVEN CREEK
- Blender 5.2.3 LTS em ~/.local/blender (headless). Skills blender-* (EL4CTEO/blender-skills, MIT) em ~/.claude/skills.
- Python 3 + Pillow 12 + numpy 2 (texturas procedurais: tools/texturas/gera_americanas.py).
- Pipeline do mapa: jogo/tools/pipeline_mapa.sh. Fotos: tools/foto_modelos.gd (modos :planta e :ver=móvel), tools/foto_cidade.gd.
