# Servidor online do jogo num serviço de site (Render, Hugging Face, Back4app...): o site (nginx) responde na
# porta $PORT e repassa /jogo (WebSocket) para o Godot sem tela. O pacote do jogo vem da branch servidor-build
# e é trocado sozinho quando sai versão nova (start.sh).
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends nginx curl unzip ca-certificates gettext-base \
	&& rm -rf /var/lib/apt/lists/*
RUN curl -sSfL -o /tmp/g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip \
	&& unzip /tmp/g.zip -d /opt && mv /opt/Godot_v4.7.2-stable_linux.x86_64 /opt/godot && rm /tmp/g.zip
COPY nginx.conf start.sh /app/
CMD ["bash", "/app/start.sh"]
