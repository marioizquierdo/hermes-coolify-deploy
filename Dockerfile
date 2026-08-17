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

# ARGs can be override from Coolify's ENVIRONMENT variables (must set "Available at Buildtime")
ARG HERMES_VERSION=0.17.0
ARG CLAUDE_CODE_VERSION=latest

# Copy the WhatsApp bridge (vendored in this repo)
COPY scripts/whatsapp-bridge ./scripts/whatsapp-bridge

# Install WhatsApp Bridge dependencies (for Hermes' WhatsApp channel)
RUN cd scripts/whatsapp-bridge && \
    npm install

# Install Hermes Agent (globally from PyPI)
RUN pip install --retries 5 --retry-delay 10 --no-cache-dir hermes-agent[all]==${HERMES_VERSION}

# Install Honcho (needed to run multiple background services: gateway and dashboard).
RUN pip install honcho

# Install Claude Code CLI (so Hermes can delegate coding tasks to Claude Code)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && claude --version
# Persist Claude Code config/settings under Hermes persistent storage
ENV CLAUDE_CONFIG_DIR=/root/.hermes/claude

# Transfer the WhatsApp bridge to the global Python site-packages directory.
RUN cp -R /app/scripts /usr/local/lib/python3.11/site-packages/

# Procfile to run the Hermes gateway as the background process.
RUN echo 'gateway: env PORT=3001 hermes gateway run' > /root/Procfile

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the gateway process from the Procfile
CMD ["honcho", "start"]
