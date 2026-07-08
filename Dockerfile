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
    unzip \
    build-essential \
    nano \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Bun runtime (needed by robinhood-for-agents npm package)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

WORKDIR /app

# Clone ONLY the necessary frontend folders from the upstream repository
RUN git clone --filter=blob:none --sparse https://github.com/NousResearch/hermes-agent.git . && \
    git sparse-checkout set web scripts/whatsapp-bridge

# Build Hermes' Web Dashboard
RUN cd web && \
    npm install && \
    npm run build && \
    rm -rf node_modules

# Install WhatsApp Bridge dependencies (for Hermes' WhatsApp channel)
RUN cd scripts/whatsapp-bridge && \
    npm install

# Install Hermes Agent globally from PyPI
# The version ARG can be modified from Coolify's ENVIRONMENT variable (must be "Available at Buildtime")
ARG HERMES_VERSION=0.17.0
RUN pip install hermes-agent[all]==${HERMES_VERSION} honcho

# Install Claude Code CLI (so Hermes can delegate coding tasks to Claude Code)
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && claude --version
# Persist Claude Code config/settings under Hermes persistent storage
ENV CLAUDE_CONFIG_DIR=/root/.hermes/claude

# Transfer the built Node.js bridge to the global Python site-packages directory.
# Hermes works with Python, the bridge allows Hermes to call Node.js.
RUN cp -R /app/scripts /usr/local/lib/python3.11/site-packages/

# Generate a "Procfile" to run the Hermes gateway and dashboard as separate processes.
# It explicitly assigns different ports to avoid http collisions.
RUN echo 'gateway: env PORT=3001 hermes gateway run' > /root/Procfile && \
    echo 'dashboard: env PORT=3005 hermes dashboard --host 0.0.0.0 --port 3005 --no-open --insecure' >> /root/Procfile

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the Procfile (gateway and dashboard process) with "honcho" (a Python tool to simplify multi-process execution).
CMD ["honcho", "start"]
