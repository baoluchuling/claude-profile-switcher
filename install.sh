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
# 只切换账号相关配置（API URL / API Key / Model），其他 settings 保持不变

PROFILES_DIR="$HOME/.claude/profiles"
SETTINGS_FILE="$HOME/.claude/settings.json"

_cc_show_current() {
  echo "当前状态:"
  echo "  API URL: ${ANTHROPIC_BASE_URL:-<官方默认>}"
  [ -n "${ANTHROPIC_API_KEY:-}" ] && echo "  API Key: ${ANTHROPIC_API_KEY:0:8}..." || echo "  API Key: <默认登录凭证>"
  if [ -f "$SETTINGS_FILE" ]; then
    echo "  Model:   $(jq -r '.model // "default"' "$SETTINGS_FILE" 2>/dev/null)"
  fi
}

_cc_apply_profile() {
  local name="$1"
  local PROFILE_FILE="$PROFILES_DIR/$name.env"
  if [ ! -f "$PROFILE_FILE" ]; then
    echo "配置 '$name' 不存在。运行 'ccswitch list' 查看。"
    return 1
  fi

  # 清除旧值
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_API_KEY
  local _MODEL=""

  # 读取配置
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    if [ "$key" = "MODEL" ]; then
      _MODEL="$value"
    else
      export "$key=$value"
    fi
  done < "$PROFILE_FILE"

  # 更新 settings.json 中的 model
  if [ -n "$_MODEL" ] && [ -f "$SETTINGS_FILE" ]; then
    jq --arg m "$_MODEL" '.model = $m' "$SETTINGS_FILE" > /tmp/_claude_settings_tmp.json && \
      mv /tmp/_claude_settings_tmp.json "$SETTINGS_FILE"
  fi

  echo "✅ 已切换到: $name"
  _cc_show_current
}

case "${1:-}" in
  list|-l)
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
    local PROFILE_FILE="$PROFILES_DIR/$2.env"
    if [ -f "$PROFILE_FILE" ]; then
      echo "配置 '$2' 已存在，请用 ccswitch -e $2 编辑。"
      return 1 2>/dev/null || exit 1
    fi
    mkdir -p "$PROFILES_DIR"
    cat > "$PROFILE_FILE" << 'TEMPLATE'
# 描述写在这里
# 留空或注释掉的变量会恢复默认值

#ANTHROPIC_BASE_URL=https://your-provider.com/v1
#ANTHROPIC_API_KEY=sk-xxx
#MODEL=opus
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
    local PROFILE_FILE="$PROFILES_DIR/$2.env"
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
    local PROFILE_FILE="$PROFILES_DIR/$2.env"
    if [ ! -f "$PROFILE_FILE" ]; then
      echo "配置 '$2' 不存在。"
      return 1 2>/dev/null || exit 1
    fi
    rm "$PROFILE_FILE"
    echo "✅ 已删除配置: $2"
    ;;

  -h|--help)
    echo "Claude Code Profile Switcher"
    echo ""
    echo "用法:"
    echo "  ccswitch <名称>        切换到指定配置"
    echo "  ccswitch -l            列出所有配置和当前状态"
    echo "  ccswitch -c <名称>     创建新配置"
    echo "  ccswitch -e <名称>     编辑配置文件"
    echo "  ccswitch -d <名称>     删除配置"
    echo "  ccswitch -h            显示帮助"
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
# 不设置 URL 和 Key，切换到此配置会 unset 它们，自动回退到 OAuth
MODEL=opus
EOF
  fi

  if [ ! -f "$PROFILES_DIR/thirdparty.env" ]; then
    cat > "$PROFILES_DIR/thirdparty.env" << 'EOF'
# 第三方供应商（请修改为你的配置）
ANTHROPIC_BASE_URL=https://your-provider.com/v1
ANTHROPIC_API_KEY=sk-your-key-here
MODEL=opus
EOF
  fi
}

# ── 写入 shell rc ──────────────────────────────────────────
install_alias() {
  detect_shell_rc
  if [ -z "$SHELL_RC" ]; then
    echo "⚠️  无法检测 shell 配置文件（登录 shell: $SHELL）"
    echo "   请手动添加: alias ccswitch='source $SWITCH_SCRIPT'"
    return
  fi

  ALIAS_LINE="alias ccswitch='source $SWITCH_SCRIPT'"
  if grep -qF "ccswitch" "$SHELL_RC" 2>/dev/null; then
    echo "alias 已存在于 $SHELL_RC，跳过。"
  else
    echo "" >> "$SHELL_RC"
    echo "# Claude Code Profile Switcher" >> "$SHELL_RC"
    echo "$ALIAS_LINE" >> "$SHELL_RC"
    echo "已写入 $SHELL_RC"
  fi
}

# ── 执行安装 ────────────────────────────────────────────────
echo "=== Claude Code Profile Switcher 安装 ==="
echo ""

create_default_profiles
install_switch_script
install_alias

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
echo "  3. 切换: ccswitch official / ccswitch thirdparty"
echo "  4. 添加更多: ccswitch -c <名称>"
