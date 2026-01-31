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
