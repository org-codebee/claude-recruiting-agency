#!/usr/bin/env bash
set -euo pipefail

# ─── Recruiting Agency — Installer ───────────────────────────────────────────
# Installs the /recruiting slash command and its three core agents.
#
# Works in two modes:
#   LOCAL  — run from a cloned repo (files copied from disk)
#   REMOTE — piped from GitHub (files downloaded via curl)
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash -s -- user
#   curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash -s -- project ~/my-app
# ──────────────────────────────────────────────────────────────────────────────

# ─── Configuration ───────────────────────────────────────────────────────────

GITHUB_OWNER="${RECRUITING_GITHUB_OWNER:-org-codebee}"
GITHUB_REPO="${RECRUITING_GITHUB_REPO:-claude-recruiting-agency}"
GITHUB_BRANCH="${RECRUITING_GITHUB_BRANCH:-main}"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Files to install (relative to repo root)
declare -A FILES=(
  [".claude/agents/victoria.md"]=".claude/agents/victoria.md"
  [".claude/agents/nathan.md"]=".claude/agents/nathan.md"
  [".claude/agents/sophia.md"]=".claude/agents/sophia.md"
  [".claude/commands/recruiting.md"]=".claude/commands/recruiting.md"
)

AGENTS=("victoria.md" "nathan.md" "sophia.md")
COMMAND_FILE="recruiting.md"

# ─── Colors ──────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  BOLD="\033[1m" GREEN="\033[0;32m" YELLOW="\033[0;33m"
  RED="\033[0;31m" CYAN="\033[0;36m" RESET="\033[0m"
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
  # When piped (non-interactive), auto-confirm
  if [[ ! -t 0 ]]; then
    return 0
  fi
  local reply
  printf "${BOLD}%s [y/N]${RESET} " "$prompt"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# ─── Mode Detection ─────────────────────────────────────────────────────────

SCRIPT_DIR=""
MODE="remote"
TMPDIR_CREATED=""

# Detect if running from a local clone
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "bash" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  CANDIDATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$CANDIDATE_DIR/.claude/agents/victoria.md" ]]; then
    SCRIPT_DIR="$CANDIDATE_DIR"
    MODE="local"
  fi
fi

# ─── File Operations ────────────────────────────────────────────────────────

download_file() {
  local url="$1" dest="$2"
  if command_exists curl; then
    curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"
  elif command_exists wget; then
    wget -q -O "$dest" "$url"
  else
    error "Neither curl nor wget found. Install one and retry."
    exit 1
  fi
}

# Download all source files to a temp directory
fetch_remote_files() {
  TMPDIR_CREATED="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR_CREATED"' EXIT

  info "Downloading files from GitHub (${GITHUB_OWNER}/${GITHUB_REPO}@${GITHUB_BRANCH})..."

  local failed=0
  for src_path in "${!FILES[@]}"; do
    local url="${GITHUB_RAW_BASE}/${src_path}"
    local dest="${TMPDIR_CREATED}/${src_path}"
    mkdir -p "$(dirname "$dest")"

    if download_file "$url" "$dest"; then
      ok "Downloaded: $src_path"
    else
      error "Failed to download: $url"
      failed=1
    fi
  done

  if [[ "$failed" -eq 1 ]]; then
    error "Some files could not be downloaded. Check the repository URL and branch."
    error "URL base: $GITHUB_RAW_BASE"
    exit 1
  fi

  SCRIPT_DIR="$TMPDIR_CREATED"
}

# Get the source directory (local or temp from download)
get_source_dir() {
  if [[ "$MODE" == "remote" ]]; then
    fetch_remote_files
  fi
}

# Install a single file with backup and diff check
install_file() {
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
    cp "$dest" "$dest.bak"
    info "Backup created: $dest.bak"
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
}

# ─── Install Functions ───────────────────────────────────────────────────────

install_project() {
  local target="$1"
  info "Installing to project: $target"

  for agent in "${AGENTS[@]}"; do
    install_file "$SCRIPT_DIR/.claude/agents/$agent" "$target/.claude/agents/$agent"
  done
  install_file "$SCRIPT_DIR/.claude/commands/$COMMAND_FILE" "$target/.claude/commands/$COMMAND_FILE"

  ok "Project installation complete: $target"
}

install_user() {
  local home_claude="$HOME/.claude"
  info "Installing to user config: $home_claude"

  for agent in "${AGENTS[@]}"; do
    install_file "$SCRIPT_DIR/.claude/agents/$agent" "$home_claude/agents/$agent"
  done
  install_file "$SCRIPT_DIR/.claude/commands/$COMMAND_FILE" "$home_claude/commands/$COMMAND_FILE"

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
  if [[ -f "$target/.claude/commands/$COMMAND_FILE" ]]; then
    rm "$target/.claude/commands/$COMMAND_FILE"
    ok "Removed: $target/.claude/commands/$COMMAND_FILE"
  fi

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
  if [[ -f "$home_claude/commands/$COMMAND_FILE" ]]; then
    rm "$home_claude/commands/$COMMAND_FILE"
    ok "Removed: $home_claude/commands/$COMMAND_FILE"
  fi

  ok "User uninstall complete."
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
  if [[ -f "$target/.claude/commands/$COMMAND_FILE" ]]; then
    printf "  ${GREEN}✓${RESET} commands/%s\n" "$COMMAND_FILE"
  else
    printf "  ${RED}✗${RESET} commands/%s\n" "$COMMAND_FILE"
  fi

  printf "\n${BOLD}User: %s${RESET}\n" "$home_claude"
  for agent in "${AGENTS[@]}"; do
    if [[ -f "$home_claude/agents/$agent" ]]; then
      printf "  ${GREEN}✓${RESET} agents/%s\n" "$agent"
    else
      printf "  ${RED}✗${RESET} agents/%s\n" "$agent"
    fi
  done
  if [[ -f "$home_claude/commands/$COMMAND_FILE" ]]; then
    printf "  ${GREEN}✓${RESET} commands/%s\n" "$COMMAND_FILE"
  else
    printf "  ${RED}✗${RESET} commands/%s\n" "$COMMAND_FILE"
  fi
  printf "\n"
}

# ─── Usage ───────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
${BOLD}Recruiting Agency — Installer${RESET}

${BOLD}Remote install (no git clone needed):${RESET}
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- user
  curl -fsSL .../install.sh | bash -s -- project ~/my-app

${BOLD}Local install (from cloned repo):${RESET}
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

${BOLD}Environment variables:${RESET}
  RECRUITING_GITHUB_OWNER   GitHub owner/org (default: ${GITHUB_OWNER})
  RECRUITING_GITHUB_REPO    Repository name  (default: ${GITHUB_REPO})
  RECRUITING_GITHUB_BRANCH  Branch to fetch  (default: ${GITHUB_BRANCH})

${BOLD}Examples:${RESET}
  # Remote — install globally
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/install.sh | bash -s -- user

  # Remote — install into a specific project
  curl -fsSL .../install.sh | bash -s -- project ~/my-app

  # Remote — force overwrite
  curl -fsSL .../install.sh | bash -s -- -f both

  # Local
  ./install.sh project
  ./install.sh user
  ./install.sh -f both
  ./install.sh status
EOF
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

# For status and uninstall, no source files needed
case "$COMMAND_ARG" in
  status)
    show_status "$TARGET"
    printf "${GREEN}${BOLD}Done.${RESET}\n"
    exit 0
    ;;
  uninstall)
    uninstall_project "$TARGET"
    printf "\n${GREEN}${BOLD}Done.${RESET}\n"
    exit 0
    ;;
  uninstall-user)
    uninstall_user
    printf "\n${GREEN}${BOLD}Done.${RESET}\n"
    exit 0
    ;;
  uninstall-all)
    uninstall_project "$TARGET"
    printf "\n"
    uninstall_user
    printf "\n${GREEN}${BOLD}Done.${RESET}\n"
    exit 0
    ;;
esac

# For install operations, ensure source files are available
get_source_dir

if [[ "$MODE" == "local" ]]; then
  info "Mode: local (installing from cloned repo)"
else
  info "Mode: remote (downloaded from GitHub)"
fi

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
  "")
    # Interactive mode — only works if stdin is a terminal
    if [[ -t 0 ]]; then
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
    else
      # Non-interactive (piped) without command → default to user install
      info "No command specified in non-interactive mode. Defaulting to 'user' install."
      install_user
    fi
    ;;
  *)
    error "Unknown command: $COMMAND_ARG"
    printf "\n"
    usage
    exit 1
    ;;
esac

printf "\n${GREEN}${BOLD}Done.${RESET} Run ${CYAN}/recruiting${RESET} in Claude Code to start assembling your team.\n"
