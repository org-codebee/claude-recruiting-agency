#!/usr/bin/env bash
set -euo pipefail

# ─── Recruiting Agency — Installer ───────────────────────────────────────────
# Installs the /recruiting slash command and its three core agents
# into Claude Code (project-level, user-level, or both).
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors (disabled when not a terminal)
if [[ -t 1 ]]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  RED="\033[0;31m"
  CYAN="\033[0;36m"
  RESET="\033[0m"
else
  BOLD="" GREEN="" YELLOW="" RED="" CYAN="" RESET=""
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

info()  { printf "${CYAN}[INFO]${RESET}  %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$1" >&2; }

confirm() {
  local prompt="$1"
  local reply
  printf "${BOLD}%s [y/N]${RESET} " "$prompt"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

copy_file() {
  local src="$1" dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  mkdir -p "$dest_dir"

  if [[ -f "$dest" ]]; then
    if diff -q "$src" "$dest" > /dev/null 2>&1; then
      ok "Already up to date: $dest"
      return 0
    fi
    if [[ "$FORCE" == "true" ]]; then
      warn "Overwriting: $dest"
    else
      warn "File exists: $dest"
      if ! confirm "  Overwrite?"; then
        info "Skipped: $dest"
        return 0
      fi
    fi
    cp "$src" "$dest.bak"
    info "Backup created: $dest.bak"
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
}

# ─── Source files ────────────────────────────────────────────────────────────

AGENTS=("victoria.md" "nathan.md" "sophia.md")
COMMAND="recruiting.md"

validate_source_files() {
  local missing=0
  for agent in "${AGENTS[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/.claude/agents/$agent" ]]; then
      error "Missing source: .claude/agents/$agent"
      missing=1
    fi
  done
  if [[ ! -f "$SCRIPT_DIR/.claude/commands/$COMMAND" ]]; then
    error "Missing source: .claude/commands/$COMMAND"
    missing=1
  fi
  if [[ "$missing" -eq 1 ]]; then
    error "Source files incomplete. Run this script from the repository root."
    exit 1
  fi
}

# ─── Install functions ───────────────────────────────────────────────────────

install_project() {
  local target="$1"
  info "Installing to project: $target"

  for agent in "${AGENTS[@]}"; do
    copy_file "$SCRIPT_DIR/.claude/agents/$agent" "$target/.claude/agents/$agent"
  done
  copy_file "$SCRIPT_DIR/.claude/commands/$COMMAND" "$target/.claude/commands/$COMMAND"

  ok "Project installation complete: $target"
}

install_user() {
  local home_claude="$HOME/.claude"
  info "Installing to user config: $home_claude"

  for agent in "${AGENTS[@]}"; do
    copy_file "$SCRIPT_DIR/.claude/agents/$agent" "$home_claude/agents/$agent"
  done
  copy_file "$SCRIPT_DIR/.claude/commands/$COMMAND" "$home_claude/commands/$COMMAND"

  ok "User installation complete: $home_claude"
}

uninstall_project() {
  local target="$1"
  info "Uninstalling from project: $target"

  for agent in "${AGENTS[@]}"; do
    if [[ -f "$target/.claude/agents/$agent" ]]; then
      rm "$target/.claude/agents/$agent"
      ok "Removed: $target/.claude/agents/$agent"
    fi
  done
  if [[ -f "$target/.claude/commands/$COMMAND" ]]; then
    rm "$target/.claude/commands/$COMMAND"
    ok "Removed: $target/.claude/commands/$COMMAND"
  fi

  # Clean up empty directories
  rmdir "$target/.claude/agents" 2>/dev/null && info "Removed empty: $target/.claude/agents/" || true
  rmdir "$target/.claude/commands" 2>/dev/null && info "Removed empty: $target/.claude/commands/" || true
  rmdir "$target/.claude" 2>/dev/null && info "Removed empty: $target/.claude/" || true

  ok "Project uninstall complete."
}

uninstall_user() {
  local home_claude="$HOME/.claude"
  info "Uninstalling from user config: $home_claude"

  for agent in "${AGENTS[@]}"; do
    if [[ -f "$home_claude/agents/$agent" ]]; then
      rm "$home_claude/agents/$agent"
      ok "Removed: $home_claude/agents/$agent"
    fi
  done
  if [[ -f "$home_claude/commands/$COMMAND" ]]; then
    rm "$home_claude/commands/$COMMAND"
    ok "Removed: $home_claude/commands/$COMMAND"
  fi

  ok "User uninstall complete."
}

# ─── Usage ───────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
${BOLD}Recruiting Agency — Installer${RESET}

${BOLD}Usage:${RESET}
  ./install.sh [options] <command>

${BOLD}Commands:${RESET}
  project [path]    Install into a project directory (default: current directory)
  user              Install into ~/.claude/ (available in all projects)
  both [path]       Install into both project and user scope
  uninstall [path]  Remove from project directory
  uninstall-user    Remove from ~/.claude/
  uninstall-all [p] Remove from both project and user scope
  status [path]     Show installation status

${BOLD}Options:${RESET}
  -f, --force       Overwrite existing files without prompting
  -h, --help        Show this help message

${BOLD}Examples:${RESET}
  ./install.sh project                    # Install to current directory
  ./install.sh project ~/my-app           # Install to specific project
  ./install.sh user                       # Install globally
  ./install.sh both                       # Install everywhere
  ./install.sh -f project                 # Force overwrite
  ./install.sh uninstall ~/my-app         # Remove from project
  ./install.sh status                     # Check what's installed
EOF
}

# ─── Status ──────────────────────────────────────────────────────────────────

show_status() {
  local target="${1:-.}"
  target="$(cd "$target" 2>/dev/null && pwd || echo "$target")"
  local home_claude="$HOME/.claude"

  printf "\n${BOLD}Installation Status${RESET}\n\n"

  printf "${BOLD}Project: %s${RESET}\n" "$target"
  for agent in "${AGENTS[@]}"; do
    if [[ -f "$target/.claude/agents/$agent" ]]; then
      printf "  ${GREEN}✓${RESET} agents/%s\n" "$agent"
    else
      printf "  ${RED}✗${RESET} agents/%s\n" "$agent"
    fi
  done
  if [[ -f "$target/.claude/commands/$COMMAND" ]]; then
    printf "  ${GREEN}✓${RESET} commands/%s\n" "$COMMAND"
  else
    printf "  ${RED}✗${RESET} commands/%s\n" "$COMMAND"
  fi

  printf "\n${BOLD}User: %s${RESET}\n" "$home_claude"
  for agent in "${AGENTS[@]}"; do
    if [[ -f "$home_claude/agents/$agent" ]]; then
      printf "  ${GREEN}✓${RESET} agents/%s\n" "$agent"
    else
      printf "  ${RED}✗${RESET} agents/%s\n" "$agent"
    fi
  done
  if [[ -f "$home_claude/commands/$COMMAND" ]]; then
    printf "  ${GREEN}✓${RESET} commands/%s\n" "$COMMAND"
  else
    printf "  ${RED}✗${RESET} commands/%s\n" "$COMMAND"
  fi
  printf "\n"
}

# ─── Main ────────────────────────────────────────────────────────────────────

FORCE="false"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

COMMAND_ARG="${1:-}"
TARGET="${2:-.}"

if [[ -n "$TARGET" && "$TARGET" != "." ]]; then
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd || { error "Directory not found: $TARGET"; exit 1; })"
else
  TARGET="$(pwd)"
fi

validate_source_files

case "$COMMAND_ARG" in
  project)
    install_project "$TARGET"
    ;;
  user)
    install_user
    ;;
  both)
    install_project "$TARGET"
    printf "\n"
    install_user
    ;;
  uninstall)
    uninstall_project "$TARGET"
    ;;
  uninstall-user)
    uninstall_user
    ;;
  uninstall-all)
    uninstall_project "$TARGET"
    printf "\n"
    uninstall_user
    ;;
  status)
    show_status "$TARGET"
    ;;
  "")
    printf "\n${BOLD}Recruiting Agency — Installer${RESET}\n\n"
    printf "Where would you like to install?\n\n"
    printf "  ${BOLD}1)${RESET} Project only  — %s/.claude/\n" "$TARGET"
    printf "  ${BOLD}2)${RESET} User only     — %s/.claude/\n" "$HOME"
    printf "  ${BOLD}3)${RESET} Both\n"
    printf "  ${BOLD}4)${RESET} Cancel\n\n"
    printf "${BOLD}Choice [1-4]:${RESET} "
    read -r choice
    printf "\n"
    case "$choice" in
      1) install_project "$TARGET" ;;
      2) install_user ;;
      3) install_project "$TARGET"; printf "\n"; install_user ;;
      4) info "Cancelled."; exit 0 ;;
      *) error "Invalid choice."; exit 1 ;;
    esac
    ;;
  *)
    error "Unknown command: $COMMAND_ARG"
    printf "\n"
    usage
    exit 1
    ;;
esac

printf "\n${GREEN}${BOLD}Done.${RESET} Run ${CYAN}/recruiting${RESET} in Claude Code to start assembling your team.\n"
