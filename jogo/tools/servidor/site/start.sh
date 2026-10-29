#!/bin/bash
# Baixa o pacote do jogo (em partes) da branch servidor-build, sobe o Godot sem tela (WebSocket 7861) e o nginx
# (porta $PORT). A cada 2 min: se saiu versão nova, troca o pacote e reinicia o Godot; se o Godot caiu, sobe de novo.
RAMO=https://raw.githubusercontent.com/bm8325020-lang/Claude-Code-Game-Studios/servidor-build
export PORT=${PORT:-7860}
mkdir -p /tmp/srv /tmp/www
cd /tmp/srv
baixa() {
	local n v
	v=$(curl -sSf "$RAMO/versao.txt") || return 1
	[ "$v" = "$(cat versao.txt 2>/dev/null)" ] && return 1
	n=$(curl -sSf "$RAMO/partes.txt") || return 1
	: > novo.pck
	for i in $(seq 0 $((n - 1))); do curl -sSfL "$RAMO/servidor.pck.$(printf %02d "$i")" >> novo.pck || return 1; done
	[ "$(sha256sum novo.pck | cut -d' ' -f1)" = "$v" ] || return 1
	mv novo.pck servidor.pck && echo "$v" > versao.txt
}
sobe() {
	/opt/godot --headless --main-pack /tmp/srv/servidor.pck -- dedicado ws &
	GODOT=$!
	echo "<h1>Servidor zumbi</h1><p>Pacote $(cut -c1-12 versao.txt), ligado em $(date -u)</p>" > /tmp/www/index.html
}
until baixa; do sleep 10; done
envsubst '${PORT}' < /app/nginx.conf > /tmp/nginx.conf
nginx -c /tmp/nginx.conf
sobe
while true; do
	sleep 120
	if baixa; then kill "$GODOT"; wait "$GODOT"; sobe
	elif ! kill -0 "$GODOT" 2>/dev/null; then sobe
	fi
done
