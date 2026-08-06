# dsbro

在同一套 Codex CLI 环境中使用 OpenAI Codex 和 DeepSeek V4 Flash：

```powershell
codex   # 默认 OpenAI Codex
ds      # DeepSeek V4 Flash
```

`ds` 复用主 `~/.codex` 的 sandbox、Skills、Plugins 和会话存储，只对当前进程覆盖模型与 provider。它不会写入 `forced_login_method`，不会把 ChatGPT 登录切换成 API Key 模式，也不会启动第二套 Windows sandbox。

## Windows 一键安装

前提：已经安装 `codex` 命令。

```powershell
irm https://raw.githubusercontent.com/mandgrapes/codex-deepseek-worker/main/install.ps1 | iex
```

新开一个 PowerShell 窗口，然后运行：

```powershell
ds
```

首次运行会在终端中隐藏输入 DeepSeek API Key，并通过 [DeepSeek 官方 Codex 配置脚本](https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.ps1) 获取当前 `deepseek-v4-flash` 模型目录。官方脚本只在临时 `CODEX_HOME` 中运行；提取模型目录后临时文件会被删除，主 `~/.codex/config.toml` 不会被改成 DeepSeek。

API Key 保存在 Windows 用户环境变量 `DEEPSEEK_API_KEY` 中，不会写入本仓库。

## 命令

```powershell
codex          # 正常 OpenAI Codex
ds             # DeepSeek V4 Flash，共用主 Codex sandbox
gpt            # codex 的可选别名
set_ds_key     # 更换 DeepSeek API Key
update_ds      # 更新启动器并重新获取 DeepSeek 官方模型目录
```

传给 `ds` 的参数会原样传给 Codex：

```powershell
ds exec --skip-git-repo-check "检查当前项目"
ds -s workspace-write
```

## 工作方式

```text
PowerShell
├── codex → ~/.codex → OpenAI provider
└── ds    → ~/.codex → DeepSeek provider（仅当前进程覆盖）
```

两者共用 Codex 的本地基础设施，但每个聊天仍是独立 session。不要用 `ds` 恢复 OpenAI 创建的线程，反之亦然；也不要让两个窗口同时修改同一个文件。

## 与旧版 dsbro 的区别

旧版使用 `Codex → MCP → 第二个 Codex → DeepSeek`，延迟和重复 token 较高。当前版本不再包含 plugin、MCP server、自定义 worker 生命周期或嵌套 Codex，会直接让当前 Codex CLI 使用 DeepSeek Responses API。

安装器会移除旧 dsbro 的 plugin/marketplace 注册，但会先备份被修改的 `config.toml`。

## 安全说明

`ds` 默认保留 Codex 的正常 sandbox 和 `OnRequest` 审批，不使用 `danger-full-access`。DeepSeek 能看到当前 session 中 Codex 发送给模型的提示、文件内容和工具结果；请按 DeepSeek 的数据政策决定哪些项目适合使用。

把远程脚本直接传给 `iex` 很方便，但会执行仓库最新代码。希望先检查内容时，可以改用：

```powershell
git clone https://github.com/mandgrapes/codex-deepseek-worker.git
cd codex-deepseek-worker
powershell -ExecutionPolicy Bypass -File .\install.ps1
```
