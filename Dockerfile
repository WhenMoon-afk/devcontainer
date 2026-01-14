# Custom devcontainer extending obra's packnplay base
# Adds: bun, uv pre-installed
FROM ghcr.io/obra/packnplay/devcontainer:latest

LABEL org.opencontainers.image.source="https://github.com/WhenMoon-afk/devcontainer-image"
LABEL org.opencontainers.image.description="Packnplay devcontainer with bun and uv pre-installed"

USER root

# Install bun
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/home/vscode/.bun bash && \
    chown -R vscode:vscode /home/vscode/.bun

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Add bun to PATH
RUN echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/vscode/.bashrc && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/vscode/.bashrc

USER vscode

# Verify
RUN /home/vscode/.bun/bin/bun --version && /usr/local/bin/uv --version

CMD ["/bin/bash"]
