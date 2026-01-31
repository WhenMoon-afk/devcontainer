# Gas Town Container
# Extends devcontainer for isolated Gas Town operation
# gt and bd binaries are mounted from host (not baked in)
#
# Build: docker build -t gastown:latest ./gastown
# Run:   See gt-* functions in shell/pnp-utils.sh

FROM ghcr.io/whenmoon-afk/devcontainer:latest

LABEL org.opencontainers.image.source="https://github.com/WhenMoon-afk/devcontainer"
LABEL org.opencontainers.image.description="Gas Town runtime container with isolated Claude agents"

USER root

# Create mount points for host binaries and directories
RUN mkdir -p /usr/local/bin/host \
    /home/vscode/gt \
    /home/vscode/Github && \
    chown -R vscode:vscode /home/vscode/gt /home/vscode/Github

# Wrapper scripts that call host-mounted binaries
RUN echo '#!/bin/bash\nexec /usr/local/bin/host/gt "$@"' > /usr/local/bin/gt && \
    echo '#!/bin/bash\nexec /usr/local/bin/host/bd "$@"' > /usr/local/bin/bd && \
    chmod +x /usr/local/bin/gt /usr/local/bin/bd

USER vscode

# Verify PATH includes our wrappers
RUN echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc

CMD ["/bin/bash"]
