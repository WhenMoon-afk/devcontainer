# Custom devcontainer extending obra's packnplay base
# Adds: bun, uv pre-installed in system PATH
FROM ghcr.io/obra/packnplay/devcontainer:latest

LABEL org.opencontainers.image.source="https://github.com/WhenMoon-afk/devcontainer"
LABEL org.opencontainers.image.description="Packnplay devcontainer with bun and uv pre-installed"

# Copy bun binary from official image (cleaner than downloading zip)
COPY --from=oven/bun:latest /usr/local/bin/bun /usr/local/bin/bun

# Install uv directly to /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Verify both are in PATH
RUN bun --version && uv --version

CMD ["/bin/bash"]
