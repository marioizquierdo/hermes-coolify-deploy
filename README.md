# Hermes Coolify Deployment

This repository provides a configuration-only template for deploying a Hermes AI Agent on [Coolify](https://coolify.io/). It utilizes a single-stage Dockerfile that installs **hermes-agent** via pip; this approach replaces complex build processes with a streamlined environment setup.

## Infrastructure Requirements

This guide focuses on a [Hetzner](https://www.hetzner.com/) cloud instance (specifically a CPX21 instance) as the reference deployment environment. However, the server infrastructure is flexible; Coolify and this Dockerfile are compatible with AWS, DigitalOcean, or any other modern VPS provider.

### Optional: Swap Memory Configuration

Allocating 2GB of swap memory is optional but highly recommended; it helps prevent out-of-memory crashes during the Docker build process.

SSH into your server and run the following commands to create and enable a swap file:

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
3. Configuration > Git Source > add `/marioizquierdo/hermes-coolify-deploy` (this repository)
4. Configuration > General > Build Pack = Docker

## Persistent Storage Configuration

Hermes requires persistent storage to maintain identity and session state across container rebuilds.

1. Navigate to the Storage section of your Coolify project.
2. Add a new volume mount mapping the host volume to the container path `/root/.hermes`.
3. Ensure the container process has write permissions for this directory.

## Environment Variables and Network Configuration

Navigate to the Environment Variables configuration in Coolify. Define the minimal variables necessary to start the container and enable the web dashboard. Below is an example subset for initial configuration:

```env
HERMES_DASHBOARD=1
HERMES_DASHBOARD_TUI=1
WHATSAPP_ENABLED=true
WHATSAPP_MODE=bot
TZ=America/Los_Angeles
```

**Critical Port Configuration**: By default, Coolify isolates containers. To access the web dashboard, navigate to the "Configuration -> General" tab of your resource in Coolify and set the "Ports Exposes" field to `3005` (use same value as in the Dockerfile dashboard process).

## Agent Model Initialization

The agent needs a model. Get an API Key from a model provider and add it to the `~/.hermes/.env` file.

Open your Coolify Terminal for the Hermes container to run hermes commands. For example, if you have a Claude/Anthropic API Key:

```
hermes config set ANTHROPIC_API_KEY sk-xxx
```

Then configure the model on `~/.hermes/.env`:

```
hermes config set model.provider anthropic
hermes config set model.default claude-3-5-sonnet-20241022
```

Alternatively, you can enable the model through the hermes chat:

1. Run the interactive chat CLI by typing `hermes chat`.
2. Type the `/model` command and follow the prompts to select your desired provider and model (for example, OpenRouter and `anthropic/claude-3.5-sonnet`, or Anthropic and `claude-3-5-sonnet-20241022`).
3. Type a simple "hello world" message to confirm the basic agent loop is functioning. Then `/exit` to end the session.

After configuring, restart the Coolify container from the dashboard so the background gateway picks up the new model state.

## WhatsApp Pairing

1. Open the Coolify Terminal.
2. Run the pairing command: `hermes whatsapp --pair`
3. A QR code will render in the terminal. Scan this QR code using the Linked Devices feature in your mobile WhatsApp application.

## Agent Initialization and Context

It is beneficial to inform Hermes about its operating environment to assist with self-improvement and debugging. You can provide this context via the dashboard or a messaging interface.

Send the following prompt to initialize its spatial awareness:
> "Remember that you are running within a Docker container orchestrated by Coolify on a Hetzner VPS. Your persistent storage is mounted at `/root/.hermes`. You have write permissions to this directory; use it to store persistent configuration and memory".

## Memory and Advanced Features

Hermes manages core context through basic text files. Use `USER.md` to define user preferences and `MEMORY.md` for long-term agent recall. For enhanced capabilities, it is recommended to install the `holographic` extension.

Advanced deployment orchestration utilizing `honcho` is supported by the ecosystem; however, this configuration should be deferred until the core agent loop and memory systems are verified and stable.
