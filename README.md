# Claude Code Profile Switcher

快速切换 Claude Code 的 API 配置（URL / Key / Model），在官方 OAuth 和多个第三方供应商之间一键切换。

只切换账号相关配置，其他 `settings.json` 中的设置（插件、权限等）保持不变。

## 安装

```bash
git clone https://github.com/baoluchuling/claude-profile-switcher.git
bash claude-profile-switcher/install.sh
source ~/.zshrc  # 或 ~/.bashrc / ~/.bash_profile
```

安装后会自动：
- 部署切换脚本到 `~/.claude/claude-switch`
- 写入 `ccswitch` alias 到 shell 配置（自动检测 zsh / bash）
- 创建 `default` 和 `thirdparty` 两个默认配置模板

### 依赖

- `jq`（用于更新 `settings.json` 中的 model）

## 使用

```bash
ccswitch                # 切回官方 OAuth
ccswitch thirdparty     # 切到第三方
ccswitch openrouter     # 切到其他配置（需先创建）
```

### 管理配置

```bash
ccswitch -c <名称>      # 创建新配置
ccswitch -e <名称>      # 编辑配置
ccswitch -d <名称>      # 删除配置
ccswitch -l             # 列出所有配置和当前状态
ccswitch -h             # 帮助
```

## 配置文件格式

配置文件存放在 `~/.claude/profiles/<名称>.env`：

```env
# 第三方供应商
ANTHROPIC_BASE_URL=https://your-provider.com/v1
ANTHROPIC_API_KEY=sk-your-key-here
MODEL=opus
```

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_BASE_URL` | API 端点，不设则使用官方端点 |
| `ANTHROPIC_API_KEY` | API 密钥，不设则回退到 OAuth 登录 |
| `MODEL` | 模型名称，写入 `~/.claude/settings.json` |

### 切换原理

| 场景 | URL | Key | 效果 |
|------|-----|-----|------|
| 官方 OAuth | 不设 | 不设 | unset 环境变量，回退 OAuth |
| 第三方 | 设 | 设 | export 环境变量，走第三方 |

## 卸载

```bash
bash claude-profile-switcher/uninstall.sh
```

## License

MIT
