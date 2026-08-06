# 请 Codex 安装 dsbro

请在 Windows PowerShell 中完成下面操作。除 DeepSeek API Key 外，不要让我手动输入其他内容。

1. 下载或更新公开仓库：

   `https://github.com/mandgrapes/codex-deepseek-worker`

2. 仓库目录固定为：

   `%LOCALAPPDATA%\Codex\marketplaces\codex-deepseek-worker`

3. 在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

4. API Key 输入窗口出现时暂停，让我输入。输入内容不得显示、复制到聊天或写入仓库。

5. 安装完成后检查 `codex-deepseek-worker` 已安装并启用，然后只告诉我重启 Codex、打开项目并输入：

```text
dsbro
```

以后更新只需在 Codex 中输入：

```text
update_dsbro
```
