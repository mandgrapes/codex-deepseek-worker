# Codex DeepSeek Worker

一个最小 Codex 插件：Codex 选择并脱敏任务上下文，调用 `deepseek-v4-flash` 生成补丁，再由 Codex 审查、应用并运行测试。

DeepSeek API 不会直接访问本地文件、终端或完整仓库。它只能看到 Codex 明确放入请求 JSON 的内容。API Key 只从本机用户环境变量读取，不保存在仓库中。

## 在另一台 Windows 机器安装

先安装并登录 GitHub CLI，然后执行：

```powershell
codex plugin marketplace add mandgrapes/codex-deepseek-worker
codex plugin add codex-deepseek-worker@codex-deepseek-worker
git clone https://github.com/mandgrapes/codex-deepseek-worker.git
cd codex-deepseek-worker
.\setup-deepseek-worker.ps1
```

重启 Codex 后，在项目中说：

> 用 DeepSeek 当小弟

之后该项目的实现任务默认考虑交给 DeepSeek，最终修改仍由 Codex 验收。

详细设计见 [CODEX_DEEPSEEK_PLUGIN_MVP.md](CODEX_DEEPSEEK_PLUGIN_MVP.md)。

