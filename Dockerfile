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

# Verify installations
RUN bun --version && uv --version && \
    vercel --version && npx convex --version && wrangler --version && \
    tmux -V

CMD ["/bin/bash"]
