# Codex 执行说明：安装 DeepSeek Worker

请直接完成下面的安装任务，不要让用户手动复制仓库地址或输入安装命令。

## 目标

从公开仓库 `https://github.com/mandgrapes/codex-deepseek-worker.git` 安装 Codex DeepSeek Worker，并配置模型 `deepseek-v4-flash`。

## 执行规则

- 这是 Windows 安装任务，请自主执行所需命令。
- 遇到 Codex 权限确认时，让用户确认即可，然后继续执行。
- 不要要求用户把 API Key 发到聊天中。
- 需要 API Key 时，运行仓库里的 `install.ps1`；它会打开独立的安全输入窗口，由用户亲自输入。
- 不需要安装 GitHub CLI，也不需要登录 GitHub。
- 除 API Key 输入外，不要向用户询问其他配置，全部使用默认值。
- 完成后检查插件状态，必须看到 `codex-deepseek-worker` 为 `installed, enabled` 才能报告成功。

## 执行步骤

1. 检查 `codex` 和 `git` 命令。
2. 如果缺少 Git，使用 Winget 安装：

   ```powershell
   winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

3. 把公开仓库克隆到临时目录。目标目录如果已经存在，先确认它确实是本任务的旧临时目录，并核对 `origin` 后执行 `pull --ff-only`；不要删除其他目录：

   ```powershell
   $workerBootstrap = Join-Path $env:TEMP "codex-deepseek-worker-bootstrap"
   git clone https://github.com/mandgrapes/codex-deepseek-worker.git $workerBootstrap
   ```

4. 运行仓库内的一文件安装器：

   ```powershell
   powershell -ExecutionPolicy Bypass -File (Join-Path $workerBootstrap "install.ps1")
   ```

5. 安装器会自动把正式副本安装到用户的本地应用数据目录、注册插件市场、安装插件，并弹出隐藏输入的 API Key 窗口。

6. 安装完成后验证：

   ```powershell
   codex plugin list
   ```

7. 告诉用户重启 Codex、开启新对话，然后输入：

   > dsbro

8. 告诉用户以后更新插件只需在 Codex 中输入：

    > update_dsbro

不要读取、回显、记录或提交用户的 API Key。
