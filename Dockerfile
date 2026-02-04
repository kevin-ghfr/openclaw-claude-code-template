# OpenClaw + Claude Code CLI
# Utilise votre abonnement Claude Pro/Max au lieu de l'API payante
#
# Le token OAuth (sk-ant-oat01-...) passe par Claude Code CLI
# car il ne peut pas etre utilise directement avec l'API Anthropic.

FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git bash curl python3 make g++ procps \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw officiel
RUN npm install -g openclaw@latest

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Verify
RUN which openclaw && openclaw --version && which claude && claude --version

RUN mkdir -p /home/node/.claude \
             /home/node/.openclaw \
             /home/node/.openclaw/agents/main/sessions \
             /home/node/.openclaw/credentials \
             /home/node/workspace && \
    chown -R node:node /home/node

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER node
ENV HOME=/home/node
WORKDIR /home/node

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=120s \
    CMD pgrep -f openclaw || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
