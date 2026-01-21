# Devcontainer Project

Custom devcontainer image extending obra's packnplay base. Published to `ghcr.io/whenmoon-afk/devcontainer:latest`.

## Quick Reference

**Build & Deploy**: Push to `main` triggers GitHub Actions to build and push the image automatically. No manual docker push needed.

**Local Testing**:
```bash
docker build -t ghcr.io/whenmoon-afk/devcontainer:latest .
```

## Architecture

### Image Contents
- Base: `ghcr.io/obra/packnplay/devcontainer:latest` (Node.js, Claude Code, other AI CLIs)
- Added: bun, uv, tmux, vercel, convex, wrangler
- PATH includes `/home/vscode/.claude/bin` for custom scripts

### Related Files

**Host utilities** (in `shell/pnp-utils.sh`, sourced in user's .bashrc):
- `pnp` - Launch Claude in container with auto port allocation
- `pnp-orchestrator` - Launch with Docker socket access for spawning child containers
- `pnp-status`, `pnp-stop`, `pnp-clean`, `pnp-attach` - Container management
- `pnp-ports`, `pnp-open` - Port utilities

**In-container scripts** (in `~/.claude/bin/`, bind-mounted into containers):
- `pnp-prompt` - Run Claude with custom system prompts
- `pnp-spawn` - Spawn worker containers (requires orchestrator mode)
- `pnp-ask` - Quick non-interactive Claude query
- `pnp-fetch`, `pnp-peers`, `pnp-post` - Inter-container communication

## Common Tasks

### Add a new tool to the image
1. Edit `Dockerfile`
2. Push to `main` - CI builds and pushes automatically
3. Run `pnp-stop --all` to stop existing containers
4. Next `pnp` invocation pulls new image

### Add a new pnp-* command for use inside containers
1. Create script in `~/.claude/bin/` with `#!/bin/bash`
2. Make executable: `chmod +x ~/.claude/bin/pnp-newcmd`
3. Available immediately in all containers (bind-mounted)

### Add a new pnp-* command for host use
1. Add function to `shell/pnp-utils.sh`
2. Run `source ~/Github/devcontainer/shell/pnp-utils.sh` to reload
