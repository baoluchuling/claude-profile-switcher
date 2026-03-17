#!/bin/bash
# Claude Code Profile Switcher - 安装脚本
# 用法: bash install.sh

set -e

CLAUDE_DIR="$HOME/.claude"
PROFILES_DIR="$CLAUDE_DIR/profiles"
SWITCH_SCRIPT="$CLAUDE_DIR/claude-switch"

# ── 检测 shell rc 文件 ──────────────────────────────────────
detect_shell_rc() {
  case "$(basename "$SHELL")" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash)
      if [ "$(uname)" = "Darwin" ]; then
        SHELL_RC="$HOME/.bash_profile"
      else
        SHELL_RC="$HOME/.bashrc"
      fi
      ;;
    *)    SHELL_RC="" ;;
  esac
}

# ── 安装主脚本 ──────────────────────────────────────────────
install_switch_script() {
  mkdir -p "$PROFILES_DIR"

  cat > "$SWITCH_SCRIPT" << 'SCRIPTEOF'
#!/bin/bash
# Claude Code Profile Switcher
# 通过环境变量切换 API 配置，不修改 settings.json

PROFILES_DIR="$HOME/.claude/profiles"

_cc_show_current() {
  echo "当前状态:"
  echo "  API URL: ${ANTHROPIC_BASE_URL:-<官方默认>}"
  [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ] && echo "  Token:   ${ANTHROPIC_AUTH_TOKEN:0:8}..." || echo "  Token:   <默认登录凭证>"
  echo "  Model:   ${ANTHROPIC_MODEL:-<默认>}"
}

_cc_apply_profile() {
  local name="$1"
  local PROFILE_FILE="$PROFILES_DIR/$name.env"
  if [ ! -f "$PROFILE_FILE" ]; then
    echo "配置 '$name' 不存在。运行 'ccswitch -l' 查看。"
    return 1
  fi

  # 清除旧值
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset ANTHROPIC_MODEL

  # 读取配置并 export
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    export "$key=$value"
  done < "$PROFILE_FILE"

  # 记住当前配置，新终端自动加载
  echo "$name" > "$PROFILES_DIR/.current"

  echo "✅ 已切换到: $name"
  _cc_show_current
}

case "${1:-}" in
  -l)
    echo "可用配置:"
    for f in "$PROFILES_DIR"/*.env; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .env)
      desc=$(head -1 "$f" | sed 's/^# *//')
      echo "  $name  —  $desc"
    done
    echo ""
    _cc_show_current
    ;;

  -c)
    if [ -z "${2:-}" ]; then
      echo "用法: ccswitch -c <名称>"
      return 1 2>/dev/null || exit 1
    fi
    PROFILE_FILE="$PROFILES_DIR/$2.env"
    if [ -f "$PROFILE_FILE" ]; then
      echo "配置 '$2' 已存在，请用 ccswitch -e $2 编辑。"
      return 1 2>/dev/null || exit 1
    fi
    mkdir -p "$PROFILES_DIR"
    cat > "$PROFILE_FILE" << 'TEMPLATE'
# 描述写在这里
# 留空或注释掉的变量会恢复默认值

#ANTHROPIC_BASE_URL=https://your-provider.com/
#ANTHROPIC_AUTH_TOKEN=sk-xxx
#ANTHROPIC_MODEL=model-name
TEMPLATE
    echo "✅ 已创建配置: $2"
    echo "   文件: $PROFILE_FILE"
    echo "   编辑: ccswitch -e $2"
    echo "   切换: ccswitch $2"
    ;;

  -e)
    if [ -z "${2:-}" ]; then
      echo "用法: ccswitch -e <名称>"
      return 1 2>/dev/null || exit 1
    fi
    PROFILE_FILE="$PROFILES_DIR/$2.env"
    if [ ! -f "$PROFILE_FILE" ]; then
      echo "配置 '$2' 不存在。"
      return 1 2>/dev/null || exit 1
    fi
    ${EDITOR:-vi} "$PROFILE_FILE"
    ;;

  -d)
    if [ -z "${2:-}" ]; then
      echo "用法: ccswitch -d <名称>"
      return 1 2>/dev/null || exit 1
    fi
    PROFILE_FILE="$PROFILES_DIR/$2.env"
    if [ ! -f "$PROFILE_FILE" ]; then
      echo "配置 '$2' 不存在。"
      return 1 2>/dev/null || exit 1
    fi
    rm "$PROFILE_FILE"
    echo "✅ 已删除配置: $2"
    ;;

  -r)
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      echo "用法: ccswitch -r <旧名称> <新名称>"
      return 1 2>/dev/null || exit 1
    fi
    OLD_FILE="$PROFILES_DIR/$2.env"
    NEW_FILE="$PROFILES_DIR/$3.env"
    if [ ! -f "$OLD_FILE" ]; then
      echo "配置 '$2' 不存在。"
      return 1 2>/dev/null || exit 1
    fi
    if [ -f "$NEW_FILE" ]; then
      echo "配置 '$3' 已存在。"
      return 1 2>/dev/null || exit 1
    fi
    mv "$OLD_FILE" "$NEW_FILE"
    echo "✅ 已重命名: $2 → $3"
    ;;

  -h|--help)
    echo "Claude Code Profile Switcher"
    echo ""
    echo "用法:"
    echo "  ccswitch                   切回官方 OAuth（默认配置）"
    echo "  ccswitch <名称>            切换到指定配置"
    echo "  ccswitch -l                列出所有配置和当前状态"
    echo "  ccswitch -c <名称>         创建新配置"
    echo "  ccswitch -e <名称>         编辑配置文件"
    echo "  ccswitch -r <旧名> <新名>  重命名配置"
    echo "  ccswitch -d <名称>         删除配置"
    echo "  ccswitch -h                显示帮助"
    echo ""
    echo "配置文件格式 (~/.claude/profiles/<名称>.env):"
    echo "  ANTHROPIC_BASE_URL=https://your-provider.com/"
    echo "  ANTHROPIC_AUTH_TOKEN=sk-xxx"
    echo "  ANTHROPIC_MODEL=model-name"
    ;;

  "")
    # 不带参数默认切回官方
    _cc_apply_profile "default"
    ;;

  *)
    _cc_apply_profile "$1"
    ;;
esac
SCRIPTEOF

  chmod +x "$SWITCH_SCRIPT"
}

# ── 创建默认配置 ────────────────────────────────────────────
create_default_profiles() {
  mkdir -p "$PROFILES_DIR"
  if [ ! -f "$PROFILES_DIR/default.env" ]; then
    cat > "$PROFILES_DIR/default.env" << 'EOF'
# Anthropic 官方（使用 OAuth 登录凭证）
# 不设置任何变量，切换到此配置会清除它们，自动回退到 OAuth
EOF
  fi

  if [ ! -f "$PROFILES_DIR/thirdparty.env" ]; then
    cat > "$PROFILES_DIR/thirdparty.env" << 'EOF'
# 第三方供应商（请修改为你的配置）
ANTHROPIC_BASE_URL=https://your-provider.com/
ANTHROPIC_AUTH_TOKEN=sk-your-token-here
ANTHROPIC_MODEL=model-name
EOF
  fi
}

# ── 写入 shell rc（alias + 自动加载）──────────────────────
install_shell_rc() {
  detect_shell_rc
  if [ -z "$SHELL_RC" ]; then
    echo "⚠️  无法检测 shell 配置文件（登录 shell: $SHELL）"
    echo "   请手动添加以下内容到你的 shell 配置文件:"
    echo "   alias ccswitch='source $SWITCH_SCRIPT'"
    echo "   [ -f $PROFILES_DIR/.current ] && source $SWITCH_SCRIPT \$(cat $PROFILES_DIR/.current) > /dev/null 2>&1"
    return
  fi

  # 先清理旧版（如果有）
  if grep -qF "ccswitch" "$SHELL_RC" 2>/dev/null; then
    sed -i.bak '/# Claude Code Profile Switcher/d;/ccswitch/d;/claude-switch/d' "$SHELL_RC"
    rm -f "$SHELL_RC.bak"
  fi

  # 写入 alias + 自动加载
  cat >> "$SHELL_RC" << RCEOF

# Claude Code Profile Switcher
alias ccswitch='source $SWITCH_SCRIPT'
[ -f $PROFILES_DIR/.current ] && source $SWITCH_SCRIPT \$(cat $PROFILES_DIR/.current) > /dev/null 2>&1
RCEOF
  echo "已写入 $SHELL_RC（alias + 自动加载）"
}

# ── 清理旧版 symlink ──────────────────────────────────────
cleanup_old() {
  # 清理旧的 symlink（如果有）
  if [ -L "/usr/local/bin/ccswitch" ]; then
    if [ -w "/usr/local/bin" ]; then
      rm -f "/usr/local/bin/ccswitch"
    else
      sudo rm -f "/usr/local/bin/ccswitch"
    fi
    echo "已清理旧版 symlink"
  fi
}

# ── 执行安装 ────────────────────────────────────────────────
echo "=== Claude Code Profile Switcher 安装 ==="
echo ""

create_default_profiles
install_switch_script
cleanup_old
install_shell_rc

echo ""
echo "✅ 安装完成！"
echo ""
echo "默认配置:"
for f in "$PROFILES_DIR"/*.env; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .env)
  desc=$(head -1 "$f" | sed 's/^# *//')
  echo "  $name  —  $desc"
done
echo ""
echo "下一步:"
echo "  1. 运行: source ${SHELL_RC:-~/.zshrc}"
echo "  2. 编辑第三方配置: ccswitch -e thirdparty"
echo "  3. 切换: ccswitch thirdparty / ccswitch"
