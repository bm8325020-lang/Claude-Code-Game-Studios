#!/bin/bash
# Servidor do jogo de zumbi na nuvem (Oracle Cloud, Ubuntu). Colar inteiro no campo "cloud-init script" ao criar
# a máquina: instala o Godot, baixa o pacote do jogo e deixa o servidor rodando. A cada 2 minutos confere se
# saiu pacote novo na branch servidor-build do GitHub e se atualiza sozinho.
set -e
RAMO=https://raw.githubusercontent.com/bm8325020-lang/Claude-Code-Game-Studios/servidor-build
mkdir -p /opt/zumbi && cd /opt/zumbi
apt-get update -y && apt-get install -y unzip curl
ARQ=$(uname -m | sed 's/aarch64/arm64/')  # x86_64 (AMD) ou arm64 (Ampere)
curl -sSfL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.$ARQ.zip"
unzip -o godot.zip && mv "Godot_v4.7.2-stable_linux.$ARQ" godot && chmod +x godot && rm godot.zip
# o pacote vem em partes (limite de 100 MB do GitHub): servidor.pck.00, .01...
N=$(curl -sSf "$RAMO/partes.txt")
: > servidor.pck
for i in $(seq 0 $((N - 1))); do curl -sSfL "$RAMO/servidor.pck.$(printf %02d "$i")" >> servidor.pck; done
sha256sum servidor.pck | cut -d' ' -f1 > versao.txt
# porta do jogo no firewall da máquina (as imagens Ubuntu da Oracle bloqueiam tudo menos o SSH)
iptables -I INPUT 1 -p udp --dport 7777 -j ACCEPT
netfilter-persistent save || true
useradd -r -s /usr/sbin/nologin zumbi || true
chown -R zumbi /opt/zumbi
cat > /etc/systemd/system/zumbi.service <<EOF
[Unit]
Description=Servidor do jogo de zumbi
After=network-online.target
[Service]
User=zumbi
WorkingDirectory=/opt/zumbi
ExecStart=/opt/zumbi/godot --headless --main-pack /opt/zumbi/servidor.pck -- dedicado
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
cat > /opt/zumbi/atualiza.sh <<EOF
#!/bin/bash
# troca o pacote quando sai um novo (versao.txt = sha256 do pacote) e reinicia o servidor
cd /opt/zumbi
NOVA=\$(curl -sSf "$RAMO/versao.txt") || exit 0
[ "\$NOVA" = "\$(cat versao.txt 2>/dev/null)" ] && exit 0
N=\$(curl -sSf "$RAMO/partes.txt") || exit 0
: > servidor.pck.novo
for i in \$(seq 0 \$((N - 1))); do curl -sSfL "$RAMO/servidor.pck.\$(printf %02d "\$i")" >> servidor.pck.novo || exit 0; done
[ "\$(sha256sum servidor.pck.novo | cut -d' ' -f1)" = "\$NOVA" ] || { rm -f servidor.pck.novo; exit 0; }
mv servidor.pck.novo servidor.pck && echo "\$NOVA" > versao.txt && chown zumbi servidor.pck versao.txt
systemctl restart zumbi
EOF
chmod +x /opt/zumbi/atualiza.sh
echo "*/2 * * * * root /opt/zumbi/atualiza.sh" > /etc/cron.d/zumbi
systemctl daemon-reload
systemctl enable --now zumbi
