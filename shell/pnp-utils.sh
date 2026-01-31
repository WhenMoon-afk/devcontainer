#!/usr/bin/env bash
# pnp-utils.sh - PackNPlay + Claude Code workflow utilities
# Source this file from your .bashrc:
#   source ~/path/to/devcontainer/shell/pnp-utils.sh
#
# Required env vars (set in .bashrc before sourcing):
#   SUBSTRATIA_API_KEY - for momentum cloud sync

# ============== Configuration ==============
# Override these in .bashrc before sourcing if needed
PNP_HOST_USER="${PNP_HOST_USER:-$USER}"
PNP_HOST_HOME="${PNP_HOST_HOME:-$HOME}"

# ============== Port Slot System ==============
_pnp_slots() {
  case $1 in
    1)  echo "3000 5173 8000";;
    2)  echo "3001 5174 8001";;
    3)  echo "3002 5175 8002";;
    4)  echo "3003 5176 8003";;
    5)  echo "3004 5177 8004";;
    6)  echo "3010 5180 8010";;
    7)  echo "3011 5181 8011";;
    8)  echo "3012 5182 8012";;
    9)  echo "3013 5183 8013";;
    10) echo "3014 5184 8014";;
    *)  echo "3000 5173 8000";;
  esac
}

_pnp_port_in_use() {
  docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":$1->"
}

_pnp_find_slot() {
  for slot in 1 2 3 4 5 6 7 8 9 10; do
    read web vite backend <<< "$(_pnp_slots $slot)"
    if ! _pnp_port_in_use $web && ! _pnp_port_in_use $vite && ! _pnp_port_in_use $backend; then
      echo $slot
      return 0
    fi
  done
  echo "1"
}

# ============== Main Commands ==============

# Main packnplay command
# Usage: pnp [claude-flags...]
# All flags are passed through to claude (e.g., --system-prompt, --model, --agent, etc.)
pnp() {
  # Serialize all arguments for passing into container
  # Uses base64 to safely handle quotes, spaces, and special characters
  local args_b64=""
  if [[ $# -gt 0 ]]; then
    args_b64=$(printf '%s\0' "$@" | base64 -w0)
  fi

  local slot=$(_pnp_find_slot)
  read web vite backend <<< "$(_pnp_slots $slot)"

  echo "Using port slot $slot: web=$web, vite=$vite, backend=$backend"
  echo "Host user: $PNP_HOST_USER"
  [[ $# -gt 0 ]] && echo "Claude flags: $*"

  # Initial container setup with ports
  packnplay run --publish $web:3000 --publish $vite:5173 --publish $backend:8000 \
    --all-creds bash -c "exit" 2>/dev/null || true

  # Main session
  packnplay run --reconnect --all-creds bash -c "
    # Create home directory matching host username for path compatibility
    sudo mkdir -p /home/$PNP_HOST_USER 2>/dev/null || true
    sudo ln -sf /home/vscode/.claude /home/$PNP_HOST_USER/.claude 2>/dev/null || true

    # Ensure data directories exist
    mkdir -p /home/vscode/.claude/momentum \
             /home/vscode/.claude/private-journal \
             /home/vscode/.claude/superpowers 2>/dev/null || true

    # One-time native addon rebuild for this Node version
    SETUP_MARKER=\"/home/vscode/.claude/.pnp-setup-\$(node -v | tr -d 'v')\"
    if [ ! -f \"\$SETUP_MARKER\" ]; then
      echo 'First run: rebuilding native addons for Node '\$(node -v)'...'
      for plugin_dir in /home/vscode/.claude/plugins/cache/*/*/*/; do
        if [ -d \"\$plugin_dir/node_modules\" ]; then
          # Check if this plugin has any native modules
          if find \"\$plugin_dir/node_modules\" -name '*.node' -type f 2>/dev/null | head -1 | grep -q .; then
            plugin_name=\$(echo \"\$plugin_dir\" | sed 's|.*/cache/||' | sed 's|/\$||')
            echo \"  Rebuilding: \$plugin_name\"
            (cd \"\$plugin_dir\" && npm rebuild --silent 2>&1) || echo \"    (failed, continuing)\"
          fi
        fi
      done
      touch \"\$SETUP_MARKER\" 2>/dev/null || true
      echo 'Native addon setup complete.'
    fi

    # Environment
    export PATH=/home/vscode/.claude/bin:\$PATH
    export PERSONAL_SUPERPOWERS_DIR=/home/vscode/.claude/superpowers
    export MOMENTUM_DB_PATH=/home/vscode/.claude/momentum/momentum.db
    export PRIVATE_JOURNAL_DB_PATH=/home/vscode/.claude/private-journal/journal.db
    export SUBSTRATIA_API_KEY='$SUBSTRATIA_API_KEY'
    export PNP_SLOT=$slot
    export PNP_HOST_WEB=$web
    export PNP_HOST_VITE=$vite
    export PNP_HOST_BACKEND=$backend
    export PNP_HOST_USER=$PNP_HOST_USER
    export PNP_GATEWAY=host.docker.internal

    # Decode and execute with passed arguments
    ARGS_B64='$args_b64'
    if [[ -n \"\$ARGS_B64\" ]]; then
      mapfile -d '' args < <(echo \"\$ARGS_B64\" | base64 -d)
      exec claude --dangerously-skip-permissions \"\${args[@]}\"
    else
      exec claude --dangerously-skip-permissions
    fi
  "
}

# Shorthand aliases
alias pnpd='pnp --debug'
alias pnpr='pnp --resume'
alias pnpc='pnp --continue'

# Orchestrator mode - has Docker access to spawn other containers
# Usage: pnp-orchestrator [claude-flags...]
# Supports --system-file <path> which gets converted to --system-prompt
pnp-orchestrator() {
  local system_file=""
  local other_args=()

  # Parse --system-file specially, pass rest through
  while [[ $# -gt 0 ]]; do
    case $1 in
      --system-file)
        system_file="$2"
        shift 2
        ;;
      *)
        other_args+=("$1")
        shift
        ;;
    esac
  done

  # If --system-file provided, read it and add as --system-prompt
  if [[ -n "$system_file" ]]; then
    if [[ ! -f "$system_file" ]]; then
      echo "Error: System file not found: $system_file" >&2
      return 1
    fi
    other_args=(--system-prompt "$(cat "$system_file")" "${other_args[@]}")
  fi

  local args_b64=""
  if [[ ${#other_args[@]} -gt 0 ]]; then
    args_b64=$(printf '%s\0' "${other_args[@]}" | base64 -w0)
  fi

  local slot=$(_pnp_find_slot)
  read web vite backend <<< "$(_pnp_slots $slot)"

  echo "ORCHESTRATOR MODE - Docker access enabled"
  echo "Using port slot $slot: web=$web, vite=$vite, backend=$backend"

  # Get container name from current directory
  local dir_name=$(basename "$PWD")
  local container_name="pnp-orchestrator-${dir_name}"

  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "Reconnecting to existing orchestrator container..."
    docker start -ai "$container_name"
    return
  fi

  # Get docker group ID from host for socket permissions
  local docker_gid=$(stat -c '%g' /var/run/docker.sock)

  # Run with Docker socket mounted (persistent container, not --rm)
  docker run -it \
    --name "$container_name" \
    --group-add "$docker_gid" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOME/.claude:/home/vscode/.claude" \
    -v "$HOME/.gitconfig:/home/vscode/.gitconfig:ro" \
    -v "$HOME/.config/gh:/home/vscode/.config/gh:ro" \
    -v "$PWD:$PWD" \
    -w "$PWD" \
    -p $web:3000 -p $vite:5173 -p $backend:8000 \
    -e "PNP_SLOT=$slot" \
    -e "PNP_HOST_WEB=$web" \
    -e "PNP_HOST_VITE=$vite" \
    -e "PNP_HOST_BACKEND=$backend" \
    -e "PNP_HOST_USER=$PNP_HOST_USER" \
    -e "PNP_GATEWAY=host.docker.internal" \
    -e "SUBSTRATIA_API_KEY=$SUBSTRATIA_API_KEY" \
    --add-host=host.docker.internal:host-gateway \
    ghcr.io/whenmoon-afk/devcontainer:latest \
    bash -c "
      # Setup PATH and symlinks
      sudo mkdir -p /home/$PNP_HOST_USER 2>/dev/null || true
      sudo ln -sf /home/vscode/.claude /home/$PNP_HOST_USER/.claude 2>/dev/null || true

      # One-time native addon rebuild for this Node version
      SETUP_MARKER=\"/home/vscode/.claude/.pnp-setup-\$(node -v | tr -d 'v')\"
      if [ ! -f \"\$SETUP_MARKER\" ]; then
        echo 'First run: rebuilding native addons for Node '\$(node -v)'...'
        for plugin_dir in /home/vscode/.claude/plugins/cache/*/*/*/; do
          if [ -d \"\$plugin_dir/node_modules\" ]; then
            if find \"\$plugin_dir/node_modules\" -name '*.node' -type f 2>/dev/null | head -1 | grep -q .; then
              plugin_name=\$(echo \"\$plugin_dir\" | sed 's|.*/cache/||' | sed 's|/\$||')
              echo \"  Rebuilding: \$plugin_name\"
              (cd \"\$plugin_dir\" && npm rebuild --silent 2>&1) || echo \"    (failed, continuing)\"
            fi
          fi
        done
        touch \"\$SETUP_MARKER\" 2>/dev/null || true
        echo 'Native addon setup complete.'
      fi

      export PATH=/home/vscode/.claude/bin:\$PATH
      export PERSONAL_SUPERPOWERS_DIR=/home/vscode/.claude/superpowers
      export MOMENTUM_DB_PATH=/home/vscode/.claude/momentum/momentum.db
      export PRIVATE_JOURNAL_DB_PATH=/home/vscode/.claude/private-journal/journal.db

      # Decode and execute with passed arguments
      ARGS_B64='$args_b64'
      if [[ -n \"\$ARGS_B64\" ]]; then
        mapfile -d '' args < <(echo \"\$ARGS_B64\" | base64 -d)
        exec claude --dangerously-skip-permissions \"\${args[@]}\"
      else
        exec claude --dangerously-skip-permissions
      fi
    "
}

# ============== Container Management ==============

pnp-status() {
  echo "=== PackNPlay Containers ==="
  docker ps --filter "name=packnplay-" \
    --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}" 2>/dev/null || echo "No containers"
  echo ""
  echo "=== Port Slots ==="
  for slot in 1 2 3 4 5 6 7 8 9 10; do
    read web vite backend <<< "$(_pnp_slots $slot)"
    if _pnp_port_in_use $web; then
      echo "Slot $slot: IN USE (web:$web, vite:$vite, backend:$backend)"
    fi
  done
}

pnp-stop() {
  if [[ "$1" == "--all" || "$1" == "-a" ]]; then
    echo "Stopping all packnplay containers..."
    docker ps --filter "name=packnplay-" -q | xargs -r docker stop
  elif [[ -n "$1" ]]; then
    echo "Stopping container: $1"
    docker stop "$1"
  else
    echo "Usage: pnp-stop <container-name> or pnp-stop --all"
    echo ""
    echo "Running containers:"
    docker ps --filter "name=packnplay-" --format "  {{.Names}}"
  fi
}

pnp-clean() {
  echo "Removing stopped packnplay containers..."
  docker ps -a --filter "label=devcontainer.local_folder" --filter "status=exited" -q | xargs -r docker rm
  echo "Done."
}

pnp-attach() {
  if [[ -n "$1" ]]; then
    docker exec -it "$1" bash
  else
    local container=$(docker ps --filter "label=devcontainer.local_folder" --format "{{.Names}}" | head -1)
    if [[ -n "$container" ]]; then
      echo "Attaching to: $container"
      docker exec -it "$container" bash
    else
      echo "No running packnplay containers found."
    fi
  fi
}

# ============== Quick Access ==============

pnp-ports() {
  echo "=== Active Port Mappings ==="
  for slot in 1 2 3 4 5 6 7 8 9 10; do
    read web vite backend <<< "$(_pnp_slots $slot)"
    if _pnp_port_in_use $web; then
      echo ""
      echo "Slot $slot:"
      echo "  Web:     http://localhost:$web"
      echo "  Vite:    http://localhost:$vite"
      echo "  Backend: http://localhost:$backend"
    fi
  done
}

pnp-open() {
  local slot="${1:-1}"
  read web vite backend <<< "$(_pnp_slots $slot)"
  local url="http://localhost:$web"
  echo "Opening: $url"

  if command -v wslview &>/dev/null; then
    wslview "$url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url"
  elif command -v open &>/dev/null; then
    open "$url"
  else
    echo "No browser opener found. URL: $url"
  fi
}

# ============== Non-interactive ==============

pnp-ask() {
  local prompt="$1"
  if [[ -z "$prompt" ]]; then
    echo "Usage: pnp-ask \"your prompt here\""
    return 1
  fi

  packnplay run --reconnect --all-creds bash -c "
    export PATH=/home/vscode/.claude/bin:\$PATH
    export PERSONAL_SUPERPOWERS_DIR=/home/vscode/.claude/superpowers
    export MOMENTUM_DB_PATH=/home/vscode/.claude/momentum/momentum.db
    export PRIVATE_JOURNAL_DB_PATH=/home/vscode/.claude/private-journal/journal.db
    export SUBSTRATIA_API_KEY='$SUBSTRATIA_API_KEY'
    claude -p '$prompt' --dangerously-skip-permissions
  "
}

# ============== Help ==============

pnp-help() {
  cat << 'EOF'
PackNPlay + Claude Code Utilities

MAIN COMMANDS:
  pnp [flags...]         Launch Claude in container (auto port selection)
                         All flags are passed through to claude CLI

  Common examples:
    pnp                              Plain launch
    pnp --debug                      Debug mode (alias: pnpd)
    pnp --resume                     Resume last conversation (alias: pnpr)
    pnp --continue                   Continue mode (alias: pnpc)
    pnp --model opus                 Use Opus model
    pnp --system-prompt "Be terse"   Custom system prompt
    pnp --append-system-prompt "..." Add to default prompt
    pnp --agent reviewer             Use specific agent
    pnp --verbose                    Verbose output

  Flags can be combined: pnp --debug --resume --model opus

CONTAINER MANAGEMENT:
  pnp-status             Show running containers and port slots
  pnp-stop <name>        Stop a specific container
  pnp-stop --all         Stop all packnplay containers
  pnp-clean              Remove stopped containers
  pnp-attach [name]      Attach bash to container (no Claude)

QUICK ACCESS:
  pnp-ports              Show active port mappings
  pnp-open [slot]        Open browser to web port for slot

NON-INTERACTIVE:
  pnp-ask "prompt"       Run a one-shot prompt in container

ENVIRONMENT VARIABLES (inside container):
  PNP_SLOT               Current port slot (1-10)
  PNP_HOST_WEB           Host port for web (container:3000)
  PNP_HOST_VITE          Host port for vite (container:5173)
  PNP_HOST_BACKEND       Host port for backend (container:8000)
  PNP_HOST_USER          Host username (for path compatibility)

CONFIGURATION:
  Set these in .bashrc BEFORE sourcing this file:
    PNP_HOST_USER        Override detected username
    PNP_HOST_HOME        Override detected home directory
    SUBSTRATIA_API_KEY   For momentum cloud sync

For full list of claude flags: claude --help
EOF
}

# ============== Gas Town Container ==============

# Gas Town container name
GT_CONTAINER_NAME="${GT_CONTAINER_NAME:-gastown-runtime}"
GT_CONTAINER_IMAGE="${GT_CONTAINER_IMAGE:-gastown:latest}"

# Start Gas Town in container
# Usage: gt-up
gt-up() {
  # Check if container exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
      echo "Gas Town container already running."
      echo "Use 'gt-attach' to connect, or 'gt-down' to stop."
      return 0
    else
      echo "Starting existing Gas Town container..."
      docker start "$GT_CONTAINER_NAME"
    fi
  else
    echo "Creating Gas Town container..."

    # Get docker group ID for socket permissions (if orchestrator mode needed)
    local docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")
    local docker_args=""
    if [[ -n "$docker_gid" ]]; then
      docker_args="--group-add $docker_gid -v /var/run/docker.sock:/var/run/docker.sock"
    fi

    # Verify host binaries exist
    if [[ ! -f "$HOME/go/bin/gt" ]]; then
      echo "Error: gt not found at $HOME/go/bin/gt"
      echo "Install with: cd ~/Github/gt/gastown && make build && cp gt ~/go/bin/"
      return 1
    fi
    if [[ ! -f "$HOME/go/bin/bd" ]]; then
      echo "Error: bd not found at $HOME/go/bin/bd"
      echo "Install with: go install github.com/steveyegge/beads/cmd/bd@latest"
      return 1
    fi

    docker run -d \
      --name "$GT_CONTAINER_NAME" \
      --hostname gastown \
      $docker_args \
      -v "$HOME/go/bin/gt:/usr/local/bin/host/gt:ro" \
      -v "$HOME/go/bin/bd:/usr/local/bin/host/bd:ro" \
      -v "$HOME/gt:/home/vscode/gt" \
      -v "$HOME/Github:/home/vscode/Github" \
      -v "$HOME/.claude:/home/vscode/.claude" \
      -v "$HOME/.gitconfig:/home/vscode/.gitconfig:ro" \
      -v "$HOME/.config/gh:/home/vscode/.config/gh:ro" \
      -v "$HOME/.ssh:/home/vscode/.ssh:ro" \
      -e "SUBSTRATIA_API_KEY=$SUBSTRATIA_API_KEY" \
      -e "GT_CONTAINER=1" \
      -e "HOME=/home/vscode" \
      --add-host=host.docker.internal:host-gateway \
      "$GT_CONTAINER_IMAGE" \
      bash -c "
        # Keep container running
        echo 'Gas Town container started.'

        # Symlink home directory for path compatibility
        sudo ln -sf /home/vscode /home/$PNP_HOST_USER 2>/dev/null || true

        # Start Gas Town
        cd /home/vscode/gt
        export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH

        if [ -f /home/vscode/gt/mayor/town.json ]; then
          echo 'Starting Gas Town services...'
          gt up
        else
          echo 'Gas Town not installed. Run gt-attach and then: gt install'
        fi

        # Keep container alive
        tail -f /dev/null
      "
  fi

  # Wait for container to be ready
  sleep 2
  echo ""
  gt-status
}

# Stop Gas Town container
gt-down() {
  if docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Stopping Gas Town..."
    docker exec "$GT_CONTAINER_NAME" bash -c "cd /home/vscode/gt && gt down 2>/dev/null || true"
    docker stop "$GT_CONTAINER_NAME"
    echo "Gas Town container stopped."
  else
    echo "Gas Town container is not running."
  fi
}

# Remove Gas Town container (preserves data in ~/gt)
gt-remove() {
  gt-down 2>/dev/null
  if docker ps -a --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Removing Gas Town container..."
    docker rm "$GT_CONTAINER_NAME"
    echo "Container removed. Data preserved in ~/gt"
  else
    echo "No Gas Town container to remove."
  fi
}

# Attach to Gas Town container (interactive shell)
gt-attach() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Gas Town container not running. Starting..."
    gt-up
    sleep 2
  fi

  echo "Attaching to Gas Town container..."
  echo "Commands: gt status, gt mayor attach, gt crew at"
  echo ""
  docker exec -it "$GT_CONTAINER_NAME" bash -c "
    cd /home/vscode/gt
    export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH
    exec bash
  "
}

# Run gt command in container
gt-exec() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Error: Gas Town container not running. Run 'gt-up' first."
    return 1
  fi

  docker exec "$GT_CONTAINER_NAME" bash -c "
    cd /home/vscode/gt
    export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH
    gt $*
  "
}

# Show Gas Town container status
gt-status() {
  echo "=== Gas Town Container ==="
  if docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Container: RUNNING"
    echo ""
    docker exec "$GT_CONTAINER_NAME" bash -c "
      cd /home/vscode/gt
      export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH
      gt status 2>/dev/null || echo '(Gas Town not initialized)'
    "
  else
    if docker ps -a --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
      echo "Container: STOPPED"
    else
      echo "Container: NOT CREATED"
    fi
  fi
}

# Attach to mayor inside container
gt-mayor() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Error: Gas Town container not running. Run 'gt-up' first."
    return 1
  fi

  docker exec -it "$GT_CONTAINER_NAME" bash -c "
    cd /home/vscode/gt
    export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH
    gt mayor attach
  "
}

# Build Gas Town container image
gt-build() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dockerfile_dir="$(dirname "$script_dir")/gastown"

  if [[ ! -f "$dockerfile_dir/Dockerfile" ]]; then
    echo "Error: Dockerfile not found at $dockerfile_dir/Dockerfile"
    return 1
  fi

  echo "Building Gas Town container image..."
  docker build -t "$GT_CONTAINER_IMAGE" "$dockerfile_dir"
}

# Show logs from Gas Town container
gt-logs() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${GT_CONTAINER_NAME}$"; then
    echo "Error: Gas Town container not running."
    return 1
  fi

  local follow=""
  [[ "$1" == "-f" ]] && follow="-f"

  docker exec "$GT_CONTAINER_NAME" bash -c "
    cd /home/vscode/gt
    export PATH=/usr/local/bin:/home/vscode/.claude/bin:\$PATH
    gt logs $follow
  "
}

gt-container-help() {
  cat << 'EOF'
Gas Town Container Commands

LIFECYCLE:
  gt-build             Build the Gas Town container image
  gt-up                Start Gas Town container (creates if needed)
  gt-down              Stop Gas Town container
  gt-remove            Remove container (preserves ~/gt data)

INTERACTION:
  gt-attach            Interactive shell in container
  gt-exec <cmd>        Run gt command in container (e.g., gt-exec status)
  gt-mayor             Attach to mayor session
  gt-status            Show container and Gas Town status
  gt-logs [-f]         Show/follow Gas Town logs

CONFIGURATION:
  GT_CONTAINER_NAME    Container name (default: gastown-runtime)
  GT_CONTAINER_IMAGE   Image to use (default: gastown:latest)

ISOLATION:
  Container has access to:
    ~/gt               Gas Town data (read-write)
    ~/Github           Git repositories (read-write)
    ~/.claude          Claude config (read-write)
    ~/.gitconfig       Git config (read-only)
    ~/.config/gh       GitHub CLI (read-only)
    ~/.ssh             SSH keys (read-only)

  Container CANNOT access:
    Rest of home directory
    System files
    Other user data

FIRST TIME SETUP:
  1. gt-build          Build the container image
  2. gt-up             Start the container
  3. gt-attach         Enter the container
  4. gt install        Initialize Gas Town (if needed)
  5. gt rig add ...    Add your rigs
  6. gt up             Start Gas Town services

UPDATING GT/BD:
  gt and bd binaries are mounted from host (~/go/bin/).
  Update on host and container gets updates immediately:

    # Update gt
    cd ~/Github/gt/gastown && git pull && make build && cp gt ~/go/bin/

    # Update bd
    go install github.com/steveyegge/beads/cmd/bd@latest

  No need to rebuild container image for gt/bd updates!
EOF
}
