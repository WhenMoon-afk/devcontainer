# Custom devcontainer extending obra's packnplay base
# Adds: bun, uv pre-installed in system PATH
FROM ghcr.io/obra/packnplay/devcontainer:latest

LABEL org.opencontainers.image.source="https://github.com/WhenMoon-afk/devcontainer"
LABEL org.opencontainers.image.description="Packnplay devcontainer with bun and uv pre-installed"

USER root

# Install bun directly to /usr/local/bin
RUN curl -fsSL https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip -o /tmp/bun.zip && \
    unzip /tmp/bun.zip -d /tmp && \
    mv /tmp/bun-linux-x64/bun /usr/local/bin/ && \
    chmod +x /usr/local/bin/bun && \
    rm -rf /tmp/bun.zip /tmp/bun-linux-x64

# Install uv directly to /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

USER vscode

# Verify both are in PATH
RUN bun --version && uv --version

CMD ["/bin/bash"]
