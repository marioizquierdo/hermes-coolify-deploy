FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=3000

# Install system dependencies and Node.js
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ffmpeg \
    ripgrep \
    git \
    tini \
    build-essential \
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
RUN pip install hermes-agent[all]==0.15.2

ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the dashboard and gateway
CMD ["bash", "-c", "npm run start --prefix web & hermes gateway run"]
