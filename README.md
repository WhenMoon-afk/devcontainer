# Custom Devcontainer Image

Extended [packnplay](https://github.com/obra/packnplay) devcontainer with additional tools pre-installed.

## What's Included

Everything from obra's base image, plus:

- **bun** - Fast JS/TS runtime and package manager
- **uv** - Fast Python package manager
- **tmux** - Terminal multiplexer for session persistence

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

## Auto-updates

The image rebuilds weekly (Sunday 00:00 UTC) to pick up:
- Base image updates from obra/packnplay
- Latest bun and uv versions

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

## Versions

Check installed versions:
```bash
bun --version
uv --version
tmux -V
```
