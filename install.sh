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
# 切换 API 配置：只修改 settings.json 的 env 字段，不动其他配置

PROFILES_DIR="$HOME/.claude/profiles"
SETTINGS_FILE="$HOME/.claude/settings.json"

_cc_show_current() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "settings.json 不存在"
    return
  fi
  echo "当前状态:"
  local _url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$SETTINGS_FILE" 2>/dev/null)
  local _token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN // empty' "$SETTINGS_FILE" 2>/dev/null)
  local _amodel=$(jq -r '.env.ANTHROPIC_MODEL // empty' "$SETTINGS_FILE" 2>/dev/null)
  local _model=$(jq -r '.model // empty' "$SETTINGS_FILE" 2>/dev/null)
  echo "  API URL: ${_url:-<官方默认>}"
  [ -n "$_token" ] && echo "  Token:   ${_token:0:8}..." || echo "  Token:   <默认登录凭证>"
  [ -n "$_amodel" ] && echo "  Model:   $_amodel (env)" || echo "  Model:   ${_model:-<默认>}"
}

_cc_apply_profile() {
  local name="$1"
  local PROFILE_FILE="$PROFILES_DIR/$name.env"
  if [ ! -f "$PROFILE_FILE" ]; then
    echo "配置 '$name' 不存在。运行 'ccswitch -l' 查看。"
    return 1
  fi

  # 读取 .env 文件中的值
  local _URL="" _TOKEN="" _ANTHROPIC_MODEL="" _MODEL=""
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      ANTHROPIC_BASE_URL)  _URL="$value" ;;
      ANTHROPIC_AUTH_TOKEN) _TOKEN="$value" ;;
      ANTHROPIC_MODEL)     _ANTHROPIC_MODEL="$value" ;;
      MODEL)               _MODEL="$value" ;;
    esac
  done < "$PROFILE_FILE"

  # 修改 settings.json
  local jq_filter='.'

  # env.ANTHROPIC_BASE_URL
  if [ -n "$_URL" ]; then
    jq_filter="$jq_filter | .env.ANTHROPIC_BASE_URL = \$url"
  else
    jq_filter="$jq_filter | del(.env.ANTHROPIC_BASE_URL)"
  fi
  # env.ANTHROPIC_AUTH_TOKEN
  if [ -n "$_TOKEN" ]; then
    jq_filter="$jq_filter | .env.ANTHROPIC_AUTH_TOKEN = \$token"
  else
    jq_filter="$jq_filter | del(.env.ANTHROPIC_AUTH_TOKEN)"
  fi
  # env.ANTHROPIC_MODEL
  if [ -n "$_ANTHROPIC_MODEL" ]; then
    jq_filter="$jq_filter | .env.ANTHROPIC_MODEL = \$amodel"
  else
    jq_filter="$jq_filter | del(.env.ANTHROPIC_MODEL)"
  fi
  # 顶层 model 字段：有 MODEL 则设置，否则删除
  if [ -n "$_MODEL" ]; then
    jq_filter="$jq_filter | .model = \$model"
  else
    jq_filter="$jq_filter | del(.model)"
  fi

  jq_filter="$jq_filter | if .env == {} then del(.env) else . end"

  jq --arg url "$_URL" --arg token "$_TOKEN" --arg amodel "$_ANTHROPIC_MODEL" --arg model "$_MODEL" \
    "$jq_filter" "$SETTINGS_FILE" > /tmp/_claude_settings_tmp.json && \
    mv /tmp/_claude_settings_tmp.json "$SETTINGS_FILE"

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
    echo "  ANTHROPIC_BASE_URL=https://...  写入 settings.json env"
    echo "  ANTHROPIC_AUTH_TOKEN=sk-xxx     写入 settings.json env"
    echo "  ANTHROPIC_MODEL=model-name      写入 settings.json env"
    echo "  MODEL=opus                      写入 settings.json model（官方用）"
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
# 不设置 env 变量，自动回退到 OAuth
MODEL=opus
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

# ── 安装命令（symlink）──────────────────────────────────────
install_command() {
  local LINK_DIR="/usr/local/bin"
  if [ ! -d "$LINK_DIR" ]; then
    mkdir -p "$LINK_DIR" 2>/dev/null || true
  fi
  if [ -w "$LINK_DIR" ]; then
    ln -sf "$SWITCH_SCRIPT" "$LINK_DIR/ccswitch"
  else
    sudo ln -sf "$SWITCH_SCRIPT" "$LINK_DIR/ccswitch"
  fi
  echo "命令已安装: ${LINK_DIR}/ccswitch"
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
echo "  ccswitch -h             查看所有命令"
