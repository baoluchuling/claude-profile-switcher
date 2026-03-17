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
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "settings.json 不存在"
    return
  fi
  echo "当前状态:"
  local _url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$SETTINGS_FILE" 2>/dev/null)
  local _key=$(jq -r '.env.ANTHROPIC_API_KEY // empty' "$SETTINGS_FILE" 2>/dev/null)
  local _model=$(jq -r '.model // "default"' "$SETTINGS_FILE" 2>/dev/null)
  echo "  API URL: ${_url:-<官方默认>}"
  [ -n "$_key" ] && echo "  API Key: ${_key:0:8}..." || echo "  API Key: <默认登录凭证>"
  echo "  Model:   $_model"
}

_cc_apply_profile() {
  local name="$1"
  local PROFILE_FILE="$PROFILES_DIR/$name.env"
  if [ ! -f "$PROFILE_FILE" ]; then
    echo "配置 '$name' 不存在。运行 'ccswitch -l' 查看。"
    return 1
  fi

  # 读取 .env 文件中的值
  local _URL="" _KEY="" _MODEL=""
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      ANTHROPIC_BASE_URL) _URL="$value" ;;
      ANTHROPIC_API_KEY)  _KEY="$value" ;;
      MODEL)              _MODEL="$value" ;;
    esac
  done < "$PROFILE_FILE"

  # 构建 jq 命令，全部写入 settings.json
  local jq_filter='.'

  # 设置或删除 env.ANTHROPIC_BASE_URL
  if [ -n "$_URL" ]; then
    jq_filter="$jq_filter | .env.ANTHROPIC_BASE_URL = \$url"
  else
    jq_filter="$jq_filter | del(.env.ANTHROPIC_BASE_URL)"
  fi

  # 设置或删除 env.ANTHROPIC_API_KEY
  if [ -n "$_KEY" ]; then
    jq_filter="$jq_filter | .env.ANTHROPIC_API_KEY = \$key"
  else
    jq_filter="$jq_filter | del(.env.ANTHROPIC_API_KEY)"
  fi

  # 清理空的 env 对象
  jq_filter="$jq_filter | if .env == {} then del(.env) else . end"

  # 设置 model
  if [ -n "$_MODEL" ]; then
    jq_filter="$jq_filter | .model = \$model"
  fi

  jq --arg url "$_URL" --arg key "$_KEY" --arg model "$_MODEL" \
    "$jq_filter" "$SETTINGS_FILE" > /tmp/_claude_settings_tmp.json && \
    mv /tmp/_claude_settings_tmp.json "$SETTINGS_FILE"

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

  -r)
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      echo "用法: ccswitch -r <旧名称> <新名称>"
      return 1 2>/dev/null || exit 1
    fi
    local OLD_FILE="$PROFILES_DIR/$2.env"
    local NEW_FILE="$PROFILES_DIR/$3.env"
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
    echo "  ccswitch <名称>            切换到指定配置"
    echo "  ccswitch -l                列出所有配置和当前状态"
    echo "  ccswitch -c <名称>         创建新配置"
    echo "  ccswitch -e <名称>         编辑配置文件"
    echo "  ccswitch -r <旧名> <新名>  重命名配置"
    echo "  ccswitch -d <名称>         删除配置"
    echo "  ccswitch -h                显示帮助"
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

# ── 创建 symlink ──────────────────────────────────────────
install_command() {
  local LINK_DIR="/usr/local/bin"
  if [ ! -d "$LINK_DIR" ]; then
    mkdir -p "$LINK_DIR" 2>/dev/null || true
  fi

  if [ -w "$LINK_DIR" ]; then
    ln -sf "$SWITCH_SCRIPT" "$LINK_DIR/ccswitch"
    echo "命令已安装: ${LINK_DIR}/ccswitch"
  else
    sudo ln -sf "$SWITCH_SCRIPT" "$LINK_DIR/ccswitch"
    echo "命令已安装: ${LINK_DIR}/ccswitch (sudo)"
  fi
}

# ── 清理旧版 alias ────────────────────────────────────────
cleanup_old_alias() {
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ] && grep -qF "ccswitch" "$rc"; then
      sed -i.bak '/# Claude Code Profile Switcher/d;/ccswitch/d' "$rc"
      rm -f "$rc.bak"
      echo "已清理旧版 alias: $rc"
    fi
  done
}

# ── 执行安装 ────────────────────────────────────────────────
echo "=== Claude Code Profile Switcher 安装 ==="
echo ""

create_default_profiles
install_switch_script
cleanup_old_alias
install_command

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
echo "用法:"
echo "  ccswitch                切回官方 OAuth"
echo "  ccswitch thirdparty     切到第三方"
echo "  ccswitch -e thirdparty  编辑第三方配置"
echo "  ccswitch -c <名称>      添加更多配置"
