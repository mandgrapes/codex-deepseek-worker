# Codex 执行说明：安装 DeepSeek Worker

请直接完成下面的安装任务，不要让用户手动复制仓库地址或输入安装命令。

## 目标

从 GitHub 私有仓库 `mandgrapes/codex-deepseek-worker` 安装 Codex DeepSeek Worker，并配置模型 `deepseek-v4-flash`。

## 执行规则

- 这是 Windows 安装任务，请自主执行所需命令。
- 遇到 Codex 权限确认时，让用户确认即可，然后继续执行。
- 不要要求用户把 API Key 发到聊天中。
- 需要 API Key 时，运行仓库里的 `install.ps1`；它会打开独立的安全输入窗口，由用户亲自输入。
- 如果 GitHub CLI 尚未登录，使用设备授权或网页授权；用户完成授权后继续，不要把 GitHub Token 输出到聊天中。
- 除 GitHub 首次授权和 API Key 输入外，不要向用户询问其他配置，全部使用默认值。
- 完成后检查插件状态，必须看到 `codex-deepseek-worker` 为 `installed, enabled` 才能报告成功。

## 执行步骤

1. 检查 `codex`、`git` 和 `gh` 命令。
2. 如果缺少 Git，使用 Winget 安装：

   ```powershell
   winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

3. 如果缺少 GitHub CLI，使用 Winget 安装：

   ```powershell
   winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

4. 检查 GitHub 登录状态：

   ```powershell
   gh auth status --hostname github.com
   ```

   如果尚未登录，执行：

   ```powershell
   gh auth login --hostname github.com --git-protocol https --web
   ```

5. 把私有仓库克隆到临时目录。目标目录如果已经存在，先确认它确实是本任务的旧临时目录，再安全地更新或替换；不要删除其他目录：

   ```powershell
   $workerBootstrap = Join-Path $env:TEMP "codex-deepseek-worker-bootstrap"
   gh repo clone mandgrapes/codex-deepseek-worker $workerBootstrap
   ```

6. 运行仓库内的一文件安装器：

   ```powershell
   powershell -ExecutionPolicy Bypass -File (Join-Path $workerBootstrap "install.ps1")
   ```

7. 安装器会自动把正式副本安装到用户的本地应用数据目录、注册插件市场、安装插件，并弹出隐藏输入的 API Key 窗口。

8. 安装完成后验证：

   ```powershell
   codex plugin list
   ```

9. 告诉用户重启 Codex、开启新对话，然后输入：

   > dsbro

不要读取、回显、记录或提交用户的 API Key。
