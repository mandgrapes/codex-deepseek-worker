# Codex DeepSeek Worker

一个最小 Codex 插件：Codex 选择并脱敏任务上下文，调用 `deepseek-v4-flash` 生成补丁，再由 Codex 审查、应用并运行测试。

DeepSeek API 不会直接访问本地文件、终端或完整仓库。它只能看到 Codex 明确放入请求 JSON 的内容。API Key 只从本机用户环境变量读取，不保存在仓库中。

## 在另一台 Windows 机器安装

最简单的方法是只把 [`给Codex安装.md`](给Codex安装.md) 交给另一台机器上的 Codex，然后说：

> 读取这个文件并照着完成安装。

仓库地址和命令都已写在文件中，你不需要手动输入。

也可以直接把 [`install.ps1`](install.ps1) 给那台机器上的 Codex，然后说：

> 读取并运行这个安装文件。需要授权时让我按回车，API Key 由我自己输入。

Codex 执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装器会自动检查 Git、从公开仓库下载源码、注册插件市场、安装插件，以及弹出安全的 API Key 输入窗口。不需要 GitHub 登录；除首次输入 API Key 外，不需要手动填写配置。模型固定为 `deepseek-v4-flash`。

重启 Codex 后，在项目中输入：

> dsbro

`dsbro` 不区分大小写。之后该项目的实现任务默认考虑交给 DeepSeek，最终修改仍由 Codex 验收。旧口令“用 DeepSeek 当小弟”仍可使用。

以后需要在其他机器更新插件，只需输入：

> update_dsbro

Codex 会从公开仓库拉取并重装最新版，无需 GitHub 登录；已有 API Key 不会被显示或覆盖。更新后重启 Codex 并开启新对话。

详细设计见 [CODEX_DEEPSEEK_PLUGIN_MVP.md](CODEX_DEEPSEEK_PLUGIN_MVP.md)。
