#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STACKS_DIR="$PROJECT_ROOT/stacks"
ENV_FILE="$PROJECT_ROOT/.env"
TEMPLATES_DIR="$PROJECT_ROOT/templates"
RUNTIME_DIR="$PROJECT_ROOT/.runtime"

# Stacks in dependency order
STACK_ORDER=(core metrics mail apps)

# Networks to create
NETWORKS=(proxy dns pihole mail_filter mail_archive metrics)

# ── helpers ───────────────────────────────────────────────────────────

compose_file() {
  echo "$STACKS_DIR/compose.$1.yaml"
}

compose() {
  local stack=$1; shift
  docker compose -f "$(compose_file "$stack")" --env-file "$ENV_FILE" "$@"
}

stack_for_service() {
  local service="$1"
  for stack in "${STACK_ORDER[@]}"; do
    if compose "$stack" config --services 2>/dev/null | grep -qx "$service"; then
      echo "$stack"
      return 0
    fi
  done
  return 1
}

compose_service() {
  local service="$1"
  shift

  local stack
  stack="$(stack_for_service "$service")" || {
    echo "Service not found in any stack: $service" >&2
    return 1
  }

  docker compose \
    -f "$(compose_file "$stack")" \
    --env-file "$ENV_FILE" \
    "$@"
}

validate_stack() {
  local stack=$1

  for s in "${STACK_ORDER[@]}"; do
    [[ "$s" == "$stack" ]] && return 0
  done

  echo "Unknown stack: $stack" >&2
  echo "Valid stacks: ${STACK_ORDER[*]}" >&2
  return 1
}

filter_stacks_in_order() {
  local -n requested_stacks=$1
  local -n result=$2

  result=()

  local -A requested
  for stack in "${requested_stacks[@]}"; do
    validate_stack "$stack" || return 1
    requested["$stack"]=1
  done

  for stack in "${STACK_ORDER[@]}"; do
    [[ -n "${requested[$stack]:-}" ]] && result+=("$stack")
  done
}

render_all() {
  if ! command -v envsubst &>/dev/null; then
    echo "Error: envsubst not found. Install it with: sudo apt install gettext-base"
    exit 1
  fi

  age -d -i ~/.config/age/key.txt -o "$ENV_FILE" "$ENV_FILE.enc"

  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found" >&2
    exit 1
  fi

  if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "Error: $TEMPLATES_DIR not found" >&2
    exit 1
  fi

  echo "==> Rendering templates"
  set -a; source "$ENV_FILE"; set +a
  while IFS= read -r -d '' tmpl; do
    local rel="${tmpl#"$TEMPLATES_DIR/"}"
    local dst="$RUNTIME_DIR/${rel%.tmpl}"
    mkdir -p "$(dirname "$dst")"
    echo "  render  templates/$rel -> .runtime/${rel%.tmpl}"
    envsubst < "$tmpl" > "$dst"
  done < <(find "$TEMPLATES_DIR" -name "*.tmpl" -print0)
}

# ── stack commands ────────────────────────────────────────────────────

cmd_up() {
  render_all
  if [[ $# -eq 0 ]]; then
    for stack in "${STACK_ORDER[@]}"; do
      echo "==> Starting $stack"
      compose "$stack" up -d
    done
  else
    local stacks=("$@")
    local -a filtered
    filter_stacks_in_order stacks filtered || exit 1
    for stack in "${filtered[@]}"; do
      echo "==> Starting $stack"
      compose "$stack" up -d
    done
  fi
}

cmd_down() {
  if [[ $# -eq 0 ]]; then
    for (( i=${#STACK_ORDER[@]}-1; i>=0; i-- )); do
      echo "==> Stopping ${STACK_ORDER[$i]}"
      compose "${STACK_ORDER[$i]}" down
    done
  else
    local stacks=("$@")
    local -a filtered
    filter_stacks_in_order stacks filtered || exit 1
    for (( i=${#filtered[@]}-1; i>=0; i-- )); do
      echo "==> Stopping ${filtered[$i]}"
      compose "${filtered[$i]}" down
    done
  fi
}

cmd_restart() {
  if [[ $# -eq 0 ]]; then
    for stack in "${STACK_ORDER[@]}"; do
      echo "==> Restarting $stack"
      compose "$stack" restart
    done
  else
    local stacks=("$@")
    local -a filtered
    filter_stacks_in_order stacks filtered || exit 1
    for stack in "${filtered[@]}"; do
      echo "==> Restarting $stack"
      compose "$stack" restart
    done
  fi
}

cmd_update() {
  if [[ $# -eq 0 ]]; then
    cmd_down
    for stack in "${STACK_ORDER[@]}"; do
      echo "==> Updating images for $stack"
      compose "$stack" pull --ignore-buildable
      compose "$stack" build --pull
    done
    cmd_up
  else
    local stacks=("$@")
    local -a filtered
    filter_stacks_in_order stacks filtered || exit 1

    for (( i=${#filtered[@]}-1; i>=0; i-- )); do
      echo "==> Stopping ${filtered[$i]}"
      compose "${filtered[$i]}" down
    done
    for stack in "${filtered[@]}"; do
      echo "==> Updating images for $stack"
      compose "$stack" pull --ignore-buildable
      compose "$stack" build --pull
    done
    for stack in "${filtered[@]}"; do
      echo "==> Starting $stack"
      compose "$stack" up -d
    done
  fi
}

# ── service commands ──────────────────────────────────────────────────

cmd_service_up() {
  local service="${1:-}"
  [[ -z "$service" ]] && {
    echo "Usage: homelab service up <service>"
    exit 1
  }

  render_all

  echo "==> Starting $service"
  compose_service "$service" up -d "$service"
}

cmd_service_down() {
  local service="${1:-}"
  [[ -z "$service" ]] && {
    echo "Usage: homelab service down <service>"
    exit 1
  }

  echo "==> Stopping $service"
  compose_service "$service" down "$service"
}

cmd_service_restart() {
  local service="${1:-}"
  [[ -z "$service" ]] && {
    echo "Usage: homelab service restart <service>"
    exit 1
  }

  echo "==> Restarting $service"
  compose_service "$service" restart "$service"
}

cmd_service_logs() {
  local service="${1:-}"
  [[ -z "$service" ]] && {
    echo "Usage: homelab service logs <service>"
    exit 1
  }

  compose_service "$service" logs -f "$service"
}

# ── provisioning commands ─────────────────────────────────────────────

cmd_networks() {
  echo "==> Creating networks"
  for net in "${NETWORKS[@]}"; do
    if docker network inspect "$net" &>/dev/null; then
      echo "  skip    $net (already exists)"
    else
      docker network create "$net"
      echo "  created $net"
    fi
  done
}

cmd_install() {
  local script_path="$SCRIPT_DIR/homelab.sh"
  local bin_path="/usr/local/bin/homelab"
 
  if [[ ! -x "$script_path" ]]; then
    chmod +x "$script_path"
    echo "Made $script_path executable"
  fi
 
  if sudo ln -sf "$script_path" "$bin_path"; then
    echo "Installed: $bin_path -> $script_path"
    echo "You can now run 'homelab' from anywhere"
  else
    echo "Failed to create symlink. Try: sudo ln -sf $script_path $bin_path"
    exit 1
  fi
}

# ── usage ─────────────────────────────────────────────────────────────

usage() {
  cat <<USAGE
Usage: homelab <command> [arguments]

Stack commands:
  up       [stack ...]                 Render templates and start stacks (default: all)
  down     [stack ...]                 Stop stacks in reverse order (default: all)
  restart  [stack ...]                 Restart stacks without re-rendering (default: all)
  update   [stack ...]                 Pull/rebuild images and redeploy (default: all)

Service commands:
  service up      <service>            Start a single service
  service down    <service>            Stop a single service
  service restart <service>            Restart a single service
  logs            <service>            Follow logs for a service

Provisioning:
  networks                             Create all external networks
  install                              Install homelab command to /usr/local/bin

Stacks (in dependency order): ${STACK_ORDER[*]}

Examples:
  homelab up                        Start all stacks
  homelab up core apps              Start core and apps stacks
  homelab down                      Stop all stacks in reverse order
  homelab service up traefik        Start just traefik
  homelab logs pihole               Follow pihole logs
USAGE
}

# ── entrypoint ────────────────────────────────────────────────────────

COMMAND=${1:-help}
shift || true

case "$COMMAND" in
  up)       cmd_up "$@" ;;
  down)     cmd_down "$@" ;;
  restart)  cmd_restart "$@" ;;
  update)   cmd_update "$@" ;;
  networks) cmd_networks ;;
  install)  cmd_install ;;
  logs)     cmd_service_logs "$@" ;;
  service)
    SUBCOMMAND=${1:-}
    shift || true
    case "$SUBCOMMAND" in
      up)      cmd_service_up "$@" ;;
      down)    cmd_service_down "$@" ;;
      restart) cmd_service_restart "$@" ;;
      logs)    cmd_service_logs "$@" ;;
      *)
        echo "Unknown subcommand: service ${SUBCOMMAND}"
        echo "Valid: up, down, restart, logs"
        exit 1
        ;;
    esac
    ;;
  help|--help|-h) usage ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac