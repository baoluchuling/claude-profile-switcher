#!/bin/bash
# Claude Code Profile Switcher - 卸载脚本

set -e

CLAUDE_DIR="$HOME/.claude"

echo "=== Claude Code Profile Switcher 卸载 ==="

rm -f "$CLAUDE_DIR/claude-switch" "$CLAUDE_DIR/claude-switch-init.sh"
echo "✅ 已删除脚本"

if [ -d "$CLAUDE_DIR/profiles" ]; then
  read -p "是否删除所有配置文件 ($CLAUDE_DIR/profiles/)？[y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$CLAUDE_DIR/profiles"
    echo "✅ 已删除配置目录"
  else
    echo "保留配置文件。"
  fi
fi

for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  if [ -f "$rc" ] && grep -qF "ccswitch" "$rc"; then
    sed -i.bak '/# Claude Code Profile Switcher/d;/ccswitch/d' "$rc"
    rm -f "$rc.bak"
    echo "✅ 已从 $rc 移除 alias"
  fi
done

echo ""
echo "卸载完成！重开终端生效。"
