# Claude Code Profile Switcher

快速切换 Claude Code 的 API 配置，在官方 OAuth 和多个第三方供应商之间一键切换。

通过修改 `~/.claude/settings.json` 的 `env` 字段实现，不影响插件、权限等其他配置。

## 安装

```bash
git clone https://github.com/baoluchuling/claude-profile-switcher.git
bash claude-profile-switcher/install.sh
```

安装后会自动：
- 部署切换脚本到 `~/.claude/claude-switch`
- 创建 `ccswitch` 命令（symlink 到 `/usr/local/bin`）
- 创建 `default` 和 `thirdparty` 两个默认配置模板

### 依赖

- `jq`

## 使用

```bash
ccswitch                    # 切回官方 OAuth（默认配置）
ccswitch thirdparty         # 切到第三方
ccswitch openrouter         # 切到其他配置（需先创建）
```

### 管理配置

```bash
ccswitch -l                 # 列出所有配置和当前状态
ccswitch -c <名称>          # 创建新配置
ccswitch -e <名称>          # 编辑配置
ccswitch -r <旧名> <新名>   # 重命名配置
ccswitch -d <名称>          # 删除配置
ccswitch -h                 # 帮助
```

## 配置文件格式

配置文件存放在 `~/.claude/profiles/<名称>.env`。

### 第三方供应商配置

```env
# OpenRouter
ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1/
ANTHROPIC_AUTH_TOKEN=sk-or-xxx
ANTHROPIC_MODEL=anthropic/claude-sonnet-4
```

### 官方配置（default.env）

```env
# Anthropic 官方（使用 OAuth 登录凭证）
MODEL=opus
```

### 变量说明

| 变量 | 写入位置 | 说明 |
|------|----------|------|
| `ANTHROPIC_BASE_URL` | `settings.json` → `env` | API 端点，不设则使用官方端点 |
| `ANTHROPIC_AUTH_TOKEN` | `settings.json` → `env` | API 密钥，不设则回退到 OAuth |
| `ANTHROPIC_MODEL` | `settings.json` → `env` | 第三方模型名称 |
| `MODEL` | `settings.json` → `model` | 官方模型名称（如 opus），切第三方时自动删除 |

### 切换原理

| 操作 | env 字段 | model 字段 | 效果 |
|------|----------|-----------|------|
| `ccswitch`（官方） | 清除 URL/Token/Model | 恢复为 `opus` | 回退到 OAuth |
| `ccswitch thirdparty` | 写入 URL/Token/Model | 删除 | 走第三方 API |

## 卸载

```bash
bash claude-profile-switcher/uninstall.sh
```

## License

MIT
