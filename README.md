# Hermes Coolify Deploy

A generic Infrastructure-as-Code (IaC) template to deploy the [Hermes Agent](https://github.com/NousResearch/hermes-agent) on a Hetzner VPS using Coolify.

## Architecture
This repository utilizes a configuration-only deployment model:
* **Application Logic:** Pulled directly from PyPI (`hermes-agent[all]`) and official upstream repositories via sparse checkout.
* **State Management:** All persistent data (memories, configurations, API keys) must be managed via Coolify volumes mounted to `/root/.hermes`.

## Deployment via Coolify
1. Create a new project in Coolify.
2. Connect this repository using the standard **Dockerfile** build pack.
3. Configure the required environment variables (e.g., `WHATSAPP_ENABLED`).
4. Mount a persistent volume to the `/root/.hermes` destination path.
5. Deploy.
