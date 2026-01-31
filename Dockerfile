# Custom devcontainer extending obra's packnplay base
# Adds: bun, uv, Vercel CLI, Convex CLI, Wrangler (Cloudflare), tmux
FROM ghcr.io/obra/packnplay/devcontainer:latest

LABEL org.opencontainers.image.source="https://github.com/WhenMoon-afk/devcontainer"
LABEL org.opencontainers.image.description="Packnplay devcontainer with bun, uv, and deployment CLIs"

USER root

# Install system packages (including docker CLI for orchestrator mode)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tmux \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Copy bun binary from official image (cleaner than downloading zip)
COPY --from=oven/bun:latest /usr/local/bin/bun /usr/local/bin/bun

# Install uv directly to /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Install global npm CLIs (Vercel, Convex, Wrangler)
# Using npm from base image since it's already available
RUN npm install -g vercel convex wrangler

# Copy bundled tools for agent debugging
COPY --chown=vscode:vscode tools/ /home/vscode/.local/share/devcontainer-tools/

USER vscode

# Add Claude tools bin to PATH for all sessions
RUN echo 'export PATH="/home/vscode/.claude/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="/home/vscode/.claude/bin:$PATH"' >> ~/.profile

# Auto-rebuild Claude plugin native modules when Node version differs from host
# This runs once per Node version, marker stored in bind-mounted ~/.claude
RUN cat >> ~/.bashrc << 'REBUILD_SCRIPT'

# One-time native addon rebuild for this Node version (silent, fast check)
_claude_plugin_rebuild() {
  local marker="$HOME/.claude/.node-$(node -v 2>/dev/null | tr -d 'v')"
  [ -f "$marker" ] && return 0
  [ ! -d "$HOME/.claude/plugins/cache" ] && return 0

  echo "Rebuilding Claude plugins for Node $(node -v)..."
  for pd in "$HOME"/.claude/plugins/cache/*/*/*/; do
    [ -d "$pd/node_modules" ] || continue
    find "$pd/node_modules" -name '*.node' -type f 2>/dev/null | head -1 | grep -q . || continue
    (cd "$pd" && npm rebuild --silent 2>&1) || true
  done
  touch "$marker" 2>/dev/null
}
_claude_plugin_rebuild
REBUILD_SCRIPT

# Verify installations
RUN bun --version && uv --version && \
    vercel --version && npx convex --version && wrangler --version && \
    tmux -V

CMD ["/bin/bash"]
