# dsbro — DeepSeek worker for Codex

`dsbro` makes DeepSeek V4 Flash a native Codex sub-agent for the current project. The main Codex agent stays in control: it delegates bounded implementation work, reviews the diff, and runs tests.

This version uses DeepSeek's Responses API and Codex custom agents. DeepSeek can inspect the project and use Codex tools under the same sandbox as other sub-agents. It is no longer the old “send selected source text and receive a patch” wrapper.

## Install on Windows

Give [`给Codex安装.md`](给Codex安装.md) to Codex on the target machine and ask it to follow the file. The only manual input is the DeepSeek API Key.

Or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer:

- downloads or updates the public GitHub repository;
- installs the Codex plugin;
- adds a DeepSeek Responses provider without changing the main Codex model;
- stores the API key in the Windows user environment as `DEEPSEEK_API_KEY`;
- installs metadata for `deepseek-v4-flash` only.

Restart Codex, open a project, and enter:

```text
dsbro
```

This creates `.codex/agents/worker.toml` in that project. The project-level `worker` overrides Codex's built-in worker, so normal worker delegation uses DeepSeek while the parent remains Codex. Start a new thread after first enabling it.

To update later:

```text
update_dsbro
```

No GitHub login is required because the repository is public. Existing API keys are preserved and never displayed.

## Privacy boundary

This is a real agent, so it can read files that the inherited Codex sandbox allows it to read. Do not describe it as unable to access the project. Credentials must still remain outside prompts, logs, and repository files.

Design details: [`CODEX_DEEPSEEK_PLUGIN_MVP.md`](CODEX_DEEPSEEK_PLUGIN_MVP.md).
