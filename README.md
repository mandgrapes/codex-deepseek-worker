# dsbro — DeepSeek worker for Codex

`dsbro` lets the main Codex agent assign implementation work to a DeepSeek V4 Flash Codex thread. The plugin launches Codex's built-in MCP server with native provider configuration overrides. The worker uses the normal Codex prompt, project instructions, repository tools, shell, patch tool, sandbox, and local session history. The main Codex agent reviews the diff and runs tests.

The worker thread is persistent and resumable. DeepSeek does not store a server-side conversation, but Codex stores the thread locally and reconstructs its context for follow-up turns.

## Why Codex MCP?

Codex 0.146.1 currently rejects third-party models in its built-in `spawn_agent` model router. Codex also ships a documented `codex mcp-server` command specifically for use by another agent. It exposes `codex` and `codex-reply`, keeps conversations alive across turns, and owns the thread lifecycle. `dsbro` configures that official server for DeepSeek; it does not implement its own agent manager.

## Install on Windows

Give [`给Codex安装.md`](给Codex安装.md) to Codex on the target machine, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer downloads or updates the public repository, installs the plugin without changing the main Codex configuration, stores the key in the Windows user environment, and installs DeepSeek's official `deepseek-v4-flash` Codex metadata.

Restart Codex, open a project, and enter:

```text
dsbro
```

After that, make normal implementation requests. Routine worker handoffs remain quiet.

If a DeepSeek worker takes a long time, the parent keeps the Codex MCP call active. Silence or latency alone does not trigger parent takeover; Codex takes over only after a confirmed failure, cancellation, or an explicit user request.

To update:

```text
update_dsbro
```

No GitHub login is required. Existing API keys are preserved and never displayed.

## Privacy boundary

The worker can read files allowed by its Codex sandbox. Treat it like any external model-backed coding agent: keep credentials out of repository files and prompts, and choose the provider according to its data policy.

Design details: [`CODEX_DEEPSEEK_PLUGIN_MVP.md`](CODEX_DEEPSEEK_PLUGIN_MVP.md).
