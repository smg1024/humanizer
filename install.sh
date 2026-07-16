#!/usr/bin/env bash
# Install Humanizer globally for Claude Code and Codex using symlinks.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-${CLAUDE_HOME:-$HOME/.claude}/skills}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"

DO_CLAUDE=1
DO_CODEX=1
FORCE=0
DRY_RUN=0
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

print_help() {
  cat <<'EOF'
Usage: ./install.sh [options]

Symlink the Humanizer skill into the global Claude Code and Codex skill
directories.

Options:
  --claude-only  Install only for Claude Code
  --codex-only   Install only for Codex
  --force        Back up an existing destination before replacing it
  --dry-run      Print the changes without applying them
  -h, --help     Show this help

Environment overrides:
  CLAUDE_SKILLS_DIR  Default: ${CLAUDE_HOME:-$HOME/.claude}/skills
  CODEX_SKILLS_DIR   Default: $HOME/.agents/skills
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --claude-only)
    DO_CODEX=0
    ;;
  --codex-only)
    DO_CLAUDE=0
    ;;
  --force)
    FORCE=1
    ;;
  --dry-run)
    DRY_RUN=1
    ;;
  -h | --help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    print_help >&2
    exit 2
    ;;
  esac
  shift
done

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  [ "$DRY_RUN" -eq 1 ] || "$@"
}

# Return 10 when the destination already points to the expected source.
prepare_target() {
  local destination="$1"
  local source="$2"

  if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
    echo "Already linked: $destination"
    return 10
  fi

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Refusing to replace existing path: $destination" >&2
      echo "Re-run with --force to move it to $destination.bak.$TIMESTAMP first." >&2
      return 1
    fi
    run mv "$destination" "$destination.bak.$TIMESTAMP"
  fi
}

install_skill() {
  local source="$1"
  local destination="$2"
  local status=0

  if [ ! -f "$source/SKILL.md" ]; then
    echo "Missing skill entry point: $source/SKILL.md" >&2
    return 1
  fi

  run mkdir -p "$(dirname "$destination")"
  prepare_target "$destination" "$source" || status=$?
  [ "$status" -eq 10 ] && return 0
  [ "$status" -eq 0 ] || return "$status"

  run ln -s "$source" "$destination"
  echo "Installed: $destination"
}

if [ "$DO_CLAUDE" -eq 1 ]; then
  echo "== Claude Code =="
  install_skill "$REPO/claude/skills/humanizer" "$CLAUDE_SKILLS_DIR/humanizer"
fi

if [ "$DO_CODEX" -eq 1 ]; then
  echo "== Codex =="
  install_skill "$REPO/codex/skills/humanizer" "$CODEX_SKILLS_DIR/humanizer"
fi

echo "Done. Restart Claude Code or Codex if the skill is not detected immediately."
