#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Detect platforms ──────────────────────────────────────────────────────────

PLATFORMS=()

[ -d "$HOME/.claude" ]          && PLATFORMS+=("claude-code")
command -v opencode &>/dev/null && PLATFORMS+=("opencode")

echo "Zone Skill Installer"
echo "===================="

if [ ${#PLATFORMS[@]} -eq 0 ]; then
  echo ""
  echo "No supported AI coding platforms detected."
  echo "Supported: Claude Code (https://claude.ai/code), OpenCode (https://opencode.ai)"
  exit 1
fi

echo "Detected: ${PLATFORMS[*]}"
echo ""

# ── Notion config ─────────────────────────────────────────────────────────────

echo "Notion integration (press Enter to skip)"
echo ""
read -rp "Work Tasks DB ID        : " WORK_DB_ID
read -rp "Personal Tasks DB ID    : " PERSONAL_DB_ID
read -rp "Work parent page ID     : " WORK_PARENT
read -rp "Personal parent page ID : " PERSONAL_PARENT
echo ""

NOTION_CONFIGURED=false
if [ -n "$WORK_DB_ID" ] || [ -n "$PERSONAL_DB_ID" ]; then
  NOTION_CONFIGURED=true
else
  echo "Notion skipped — use --no-notion or re-run installer to configure later."
  echo ""
fi

# ── Write Notion IDs to platform-native config ────────────────────────────────
# Each platform stores env vars in its own config; no shared ~/.zone/config.json needed.

write_claude_settings() {
  local settings="$HOME/.claude/settings.json"
  python3 - "$WORK_DB_ID" "$PERSONAL_DB_ID" "$WORK_PARENT" "$PERSONAL_PARENT" <<'PYEOF'
import json, os, sys
path = os.path.expanduser('~/.claude/settings.json')
s = json.load(open(path)) if os.path.exists(path) else {}
keys = ['ZONE_NOTION_WORK_DB_ID','ZONE_NOTION_PERSONAL_DB_ID',
        'ZONE_NOTION_WORK_PARENT_ID','ZONE_NOTION_PERSONAL_PARENT_ID']
s.setdefault('env', {}).update(dict(zip(keys, sys.argv[1:])))
json.dump(s, open(path, 'w'), indent=2)
PYEOF
  echo "  Notion env vars → $settings"
}

write_shell_profile() {
  local profile="${HOME}/.zshrc"
  [ ! -f "$profile" ] && profile="${HOME}/.bashrc"
  [ ! -f "$profile" ] && profile="${HOME}/.profile"

  cat >> "$profile" <<SHEOF

# zone-skill Notion config
export ZONE_NOTION_WORK_DB_ID='$WORK_DB_ID'
export ZONE_NOTION_PERSONAL_DB_ID='$PERSONAL_DB_ID'
export ZONE_NOTION_WORK_PARENT_ID='$WORK_PARENT'
export ZONE_NOTION_PERSONAL_PARENT_ID='$PERSONAL_PARENT'
SHEOF
  echo "  Notion env vars → $profile  (run: source $profile)"
}

if $NOTION_CONFIGURED; then
  for platform in "${PLATFORMS[@]}"; do
    case $platform in
      claude-code) write_claude_settings ;;
      opencode)    write_shell_profile ;;
    esac
  done
fi

# ── Install skill files ───────────────────────────────────────────────────────

install_to() {
  local cmd_dir="$1"
  mkdir -p "$cmd_dir/zone"
  # Substitute ZONE_COMMANDS_DIR placeholder with the actual install path
  sed "s|ZONE_COMMANDS_DIR|$cmd_dir|g" "$SCRIPT_DIR/zone.md" > "$cmd_dir/zone.md"
  cp "$SCRIPT_DIR/zone/"*.md "$cmd_dir/zone/"
}

echo "Installing skill files..."
for platform in "${PLATFORMS[@]}"; do
  case $platform in
    claude-code)
      install_to "$HOME/.claude/commands"
      echo "  ✓ Claude Code → $HOME/.claude/commands"
      ;;
    opencode)
      install_to "$HOME/.config/opencode/commands"
      echo "  ✓ OpenCode → $HOME/.config/opencode/commands"
      echo "    (verify path matches your OpenCode version)"
      ;;
  esac
done

echo ""
echo "Usage:"
echo "  /zone TICKET-123              — Jira path"
echo "  /zone                         — Scratch path"
echo "  /zone TICKET-123 --no-notion  — skip Notion for this session"
echo ""
echo "Done. You're ready to enter the Zone."
