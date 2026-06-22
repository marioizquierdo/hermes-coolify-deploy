FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Install system dependencies and Node.js
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    curl \
    ffmpeg \
    ripgrep \
    git \
    tini \
    build-essential \
    nano \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone ONLY the necessary frontend folders from the upstream repository
RUN git clone --filter=blob:none --sparse https://github.com/NousResearch/hermes-agent.git . && \
    git sparse-checkout set web scripts/whatsapp-bridge

# Build the Web Dashboard
RUN cd web && \
    npm install && \
    npm run build && \
    rm -rf node_modules

# Install WhatsApp Bridge dependencies
RUN cd scripts/whatsapp-bridge && \
    npm install

# Install Hermes Agent globally from PyPI
ARG HERMES_VERSION=0.17.0
RUN pip install hermes-agent[all]==${HERMES_VERSION} honcho

# Install Claude Code CLI
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && claude --version
# Persist Claude Code config/settings under Hermes persistent storage
ENV CLAUDE_CONFIG_DIR=/root/.hermes/claude

# Transfer the built Node.js bridge to the global Python site-packages directory
RUN cp -R /app/scripts /usr/local/lib/python3.11/site-packages/

# Generate a Procfile that explicitly sets separate ports to guarantee no collisions
RUN echo 'gateway: env PORT=3001 hermes gateway run' > /root/Procfile && \
    echo 'dashboard: env PORT=3005 hermes dashboard --host 0.0.0.0 --port 3005 --no-open --insecure' >> /root/Procfile

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the gateway and dashboard with honcho
CMD ["honcho", "start"]
