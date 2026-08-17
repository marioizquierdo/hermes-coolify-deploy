# Hermes Coolify Deployment

This repository provides a configuration-only template for deploying a [Hermes AI Agent](https://hermes-agent.nousresearch.com/) on [Coolify](https://coolify.io/). It uses a single-stage Dockerfile that installs **hermes-agent** via pip and runs the messaging gateway. The repository also vendors the **WhatsApp bridge** so the image builds without cloning the entire upstream hermes-agent repo.

The main way to chat with the agent is:

- **WhatsApp** (mobile messenger, always connected)
- **Open WebUI** (polished multi-user, multi-session chat UI in the browser), connected to Hermes's built-in **API server**

## Infrastructure Requirements

Note: the server infrastructure is flexible; Coolify and this Dockerfile are compatible with Hetzner, AWS, DigitalOcean, or any other modern VPS provider.

### Create a Hetzner instance

Create a [Hetzner](https://www.hetzner.com/) cloud instance (CPX21) as from their website, then open the Hetzner Cloud Console. From there, create a new cloud project if needed, then start a new server instance.

Use a basic Linux image such as Ubuntu 24.04 LTS. Select the CPX21 instance type, or the nearest available CPX plan with similar resources. For Coolify, choose a region close to where you expect to access or deploy from, add your SSH key.

Typical monthly pricing depends heavily on region. As of mid-2026, CPX21 in the USA is listed around $37.49/month before VAT and IPv4 charges. Budget a little extra if you need IPv4, backups, snapshots, volumes, or other paid options.

### Optional: Swap Memory Configuration

Allocating 2GB of swap memory is optional; it helps prevent out-of-memory crashes during the Docker build process. SSH into your server and run the following commands to create and enable a swap file:

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## Install Coolify

Install Coolify on your fresh VPS. For comprehensive setup details, refer to the [official Coolify installation documentation](https://coolify.io/docs/).

1. Execute the installation script:
   ```bash
   curl -fsSL [https://cdn.coollabs.io/coolify/install.sh](https://cdn.coollabs.io/coolify/install.sh) | bash
   ```
2. Access the Coolify dashboard and create a new project.
3. Configuration > Git Source > add this repository: `/marioizquierdo/hermes-coolify-deploy`
4. Configuration > General > Build Pack = Docker

## Persistent Storage Configuration

Hermes requires persistent storage to maintain identity, WhatsApp session, and state across container rebuilds.

1. Navigate to the **Storage** section of your Coolify project.
2. Add a new volume mount mapping the host volume to the container path `/root/.hermes`.
3. Ensure the container process has write permissions for this directory.

## Environment Variables

Navigate to the **Environment Variables** configuration in Coolify. Below are the key variables:

```env
WHATSAPP_ENABLED=true
WHATSAPP_MODE=bot
TZ=America/Los_Angeles
```

**API Server (for the Open WebUI frontend):** enable Hermes's built-in OpenAI-compatible API server:

```env
API_SERVER_ENABLED=true
API_SERVER_KEY=<your-super-secret-key-here>
API_SERVER_HOST=0.0.0.0
```

- `API_SERVER_KEY` authenticates clients. You can generate one with `openssl rand -hex 32`.
- `API_SERVER_HOST=0.0.0.0` binds to all interfaces so other containers (Open WebUI) on the Coolify network can reach it. Default port is `8642` (override with `API_SERVER_PORT` if needed).

## Hermes Version

The Dockerfile has a default `ARG HERMES_VERSION` value, but you can change it through a Coolify environment variable. Check what is the latest version here: https://github.com/NousResearch/hermes-agent/releases

```env
HERMES_VERSION=0.17.0
```

Make sure to enable "Available at Buildtime" on the environment variable, so the value is passed to the container. After updating and saving, re-deploy with "Force Deploy (without cache)" to restart the Docker container and install the new hermes version.

## Agent Model Initialization

The agent needs a model. Get an API Key from a model provider and add it to the `~/.hermes/.env` file.

Open your Coolify Terminal for the Hermes container to run hermes commands. For example, if you have an Anthropic API Key:

```
hermes config set ANTHROPIC_API_KEY sk-xxx
```

Then configure the default model (this writes to `~/.hermes/config.yaml`):

```
hermes config set model.provider anthropic
hermes config set model.default claude-3-5-sonnet-20241022
```

Alternatively, you can enable the model through the hermes chat:

1. Run the interactive chat CLI by typing `hermes chat`.
2. Type the `/model` command and follow the prompts to select your desired provider and model.
3. Type a simple "hello world" message to confirm the basic agent loop is functioning. Then `/exit` to end the session.

After configuring, restart the Coolify container so the background gateway picks up the new model state.

## WhatsApp Pairing

1. Open the **Coolify Terminal** for the Hermes container.
2. Run the pairing command: `hermes whatsapp`.
3. A QR code will render in the terminal. Scan this QR code using the **Linked Devices** feature in your mobile WhatsApp application.

The WhatsApp bridge lives at `scripts/whatsapp-bridge/` (vendored in this repo). Keep it in sync if the upstream bridge changes — the `package-lock.json` pins the Baileys WhatsApp library version, so don't delete it.

## Open WebUI Frontend (multi-session browser chat)

The Hermes API server exposes a full OpenAI-compatible endpoint. **Open WebUI** (or any OpenAI-compatible frontend: LibreChat, LobeChat, etc.) can talk to it.

Official docs: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/open-webui

### Deploy Open WebUI as a second Coolify service

Create a new Coolify application or service for Open WebUI from the official image `ghcr.io/open-webui/open-webui:main`, with these environment variables:

```env
OPENAI_API_BASE_URL=http://hermes:8642/v1
OPENAI_API_KEY=your-super-secret-key-here   # must match Hermes's API_SERVER_KEY
ENABLE_OLLAMA_API=false
```

Replace `hermes` with the **network alias** of the Hermes app (set it in the Hermes app: General → **Network Alias**, e.g. `hermes`). Both services must be on the same Coolify server/network. If the alias isn't set, point `OPENAI_API_BASE_URL` at the Hermes app's FQDN instead.

Expose Open WebUI's port (e.g. `3000:8080`) so you can reach it in the browser.

### First use

1. Open the Open WebUI URL and **create your admin account** (first user becomes admin).
2. Open **Admin Settings → Connections** and confirm the Hermes connection verifies.
3. Start a new chat and pick the **`hermes-agent`** model from the dropdown.
4. Open WebUI gives you a **multi-session sidebar** — each conversation is an independent agent session. Memory is shared; conversation history is per-session.

## WhatsApp Bridge Build (how this repo avoids the upstream clone)

Historically the Dockerfile did a `git clone` of the entire upstream `hermes-agent` repo just to grab the web dashboard + WhatsApp bridge. That clone was fragile and broke deploys on GitHub HTTP 429 rate-limit errors (`RPC failed; curl 22`).

To fix it, this repo:

- **Vendors `scripts/whatsapp-bridge/`** (the bridge source) so no upstream clone is needed for WhatsApp.
- **Drops the web dashboard** entirely (`npm run build` and its Procfile process are gone).

The Dockerfile copies the vendored bridge to `scripts/whatsapp-bridge`, runs `npm install` there, and transfers it into Python `site-packages/scripts/whatsapp-bridge` (where Hermes's `whatsapp.py` looks for it).

## Agent Initialization and Context

It is beneficial to inform Hermes about its operating environment to assist with self-improvement and debugging. Send the following prompt to initialize its spatial awareness:

> "Remember that you are running within a Docker container orchestrated by Coolify on a Hetzner VPS. Your persistent storage is mounted at `/root/.hermes`. You have write permissions to this directory; use it to store persistent configuration and memory".

## Memory and Advanced Features

Hermes manages core context through basic text files. Use `USER.md` to define user preferences and `MEMORY.md` for long-term agent recall. For enhanced capabilities, install the `holographic` extension.
