# dsbro — DeepSeek worker for Codex

`dsbro` lets the main Codex agent assign implementation work to a DeepSeek V4 Flash Codex thread. The worker uses DeepSeek's Responses API plus the normal Codex prompt, project instructions, repository tools, shell, patch tool, sandbox, and local session history. The main Codex agent reviews the diff and runs tests.

The worker thread is persistent and resumable. DeepSeek does not store a server-side conversation, but Codex stores the thread locally and reconstructs its context for follow-up turns.

## Why a child Codex thread?

Codex 0.146.1 currently rejects third-party models in its built-in `spawn_agent` model router. A normal `codex exec` thread does support DeepSeek's official Responses provider. `dsbro` uses that Codex runtime path, returns a session ID, and resumes the same worker for corrections or more work. It never silently substitutes an OpenAI worker.

## Install on Windows

Give [`给Codex安装.md`](给Codex安装.md) to Codex on the target machine, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer downloads or updates the public repository, installs the plugin, adds the DeepSeek provider without changing the main Codex model, stores the Key in the Windows user environment, and installs DeepSeek's official `deepseek-v4-flash` Codex metadata.

Restart Codex, open a project, and enter:

```text
dsbro
```

After that, make normal implementation requests. Routine worker handoffs remain quiet.

To update:

```text
update_dsbro
```

No GitHub login is required. Existing API keys are preserved and never displayed.

## Privacy boundary

The worker can read files allowed by its Codex sandbox. Treat it like any external model-backed coding agent: keep credentials out of repository files and prompts, and choose the provider according to its data policy.

Design details: [`CODEX_DEEPSEEK_PLUGIN_MVP.md`](CODEX_DEEPSEEK_PLUGIN_MVP.md).
