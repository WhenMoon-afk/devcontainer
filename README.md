# Custom Devcontainer Image

Extended [packnplay](https://github.com/obra/packnplay) devcontainer with deployment CLIs and debugging tools pre-installed.

## What's Included

Everything from obra's base image, plus:

### Package Managers
- **bun** - Fast JS/TS runtime and package manager
- **uv** - Fast Python package manager

### Deployment CLIs
- **vercel** - Vercel deployment CLI
- **convex** - Convex backend CLI
- **wrangler** - Cloudflare Workers/DNS CLI

### System Tools
- **tmux** - Terminal multiplexer for persistent sessions

### Bundled Debugging Tools
Located in `~/.local/share/devcontainer-tools/`:

- **console-bridge/** - Frontend-to-backend log forwarding for AI agents
- **ui-test/** - Playwright-based webapp testing tool

## Usage with packnplay

Add to `~/.config/packnplay/config.json`:

```json
{
  "default_image": "ghcr.io/whenmoon-afk/devcontainer-image:latest"
}
```

Or use per-command:

```bash
packnplay run --image ghcr.io/whenmoon-afk/devcontainer-image:latest claude
```

## Credential Setup

The deployment CLIs need authentication. Use environment variables via packnplay's env bundle feature.

### Option 1: Environment Variable Bundle

Add to `~/.config/packnplay/config.json`:

```json
{
  "default_image": "ghcr.io/whenmoon-afk/devcontainer-image:latest",
  "env_bundles": {
    "deploy": {
      "VERCEL_TOKEN": "your-vercel-token",
      "CLOUDFLARE_API_TOKEN": "your-cloudflare-token",
      "CONVEX_DEPLOY_KEY": "your-convex-deploy-key"
    }
  }
}
```

Then run with:
```bash
packnplay run --env-bundle deploy claude
```

### Option 2: Interactive Login (Per-Session)

Inside the container:
```bash
vercel login           # Opens browser for OAuth
wrangler login         # Opens browser for OAuth
npx convex login       # Opens browser for OAuth
```

### Getting API Tokens

| Service | Where to Get Token |
|---------|-------------------|
| Vercel | [vercel.com/account/tokens](https://vercel.com/account/tokens) |
| Cloudflare | [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) |
| Convex | [dashboard.convex.dev](https://dashboard.convex.dev) → Settings → Deploy Keys |

## Bundled Tools

### Console Log Bridge

Forwards browser `console.log/warn/error` to your server console so AI agents can see frontend logs without browser automation.

```bash
# Copy to your project
cp ~/.local/share/devcontainer-tools/console-bridge/frontend-shim.js src/lib/

# See backend endpoint examples
cat ~/.local/share/devcontainer-tools/console-bridge/backend-endpoints.js
```

See [tools/console-bridge/README.md](tools/console-bridge/README.md) for setup guide.

### UI Test Tool

Playwright-based testing for AI agents to check pages, take screenshots, and capture console logs.

```bash
# Install Playwright first
uv pip install playwright && playwright install chromium

# Test a page
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --screenshot test.png \
    --console
```

See [tools/ui-test/README.md](tools/ui-test/README.md) for full options.

## Auto-updates

The image rebuilds weekly (Sunday 00:00 UTC) to pick up:
- Base image updates from obra/packnplay
- Latest tool versions

## Manual Build

```bash
docker build -t my-devcontainer .
```

## Session Persistence with tmux

Run Claude inside tmux to survive disconnects:

```bash
tmux new -s claude
claude --dangerously-skip-permissions
```

Detach: `Ctrl+b d`
Reattach: `tmux a -t claude`

## Verify Installation

```bash
# Package managers
bun --version
uv --version

# Deployment CLIs
vercel --version
npx convex --version
wrangler --version

# System tools
tmux -V
```
