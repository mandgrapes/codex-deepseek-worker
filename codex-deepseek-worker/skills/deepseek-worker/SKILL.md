---
name: deepseek-worker
description: Enable, use, or update dsbro, a Codex worker thread powered by DeepSeek V4 Flash through the Responses API. Use when the user says "dsbro", "update_dsbro", asks to use DeepSeek as a coding worker, or when a project AGENTS.md activates dsbro for implementation work.
---

# dsbro

`dsbro` uses Codex's built-in MCP server to run `deepseek-v4-flash` in a normal Codex coding session. It gets the Codex agent prompt, project instructions, repository tools, patch tool, shell, sandbox, and local conversation history. The parent Codex session delegates, reviews, and accepts the work.

DeepSeek's Responses endpoint does not store server-side conversations, but Codex stores the worker thread locally. Resume calls reconstruct the conversation, so the worker can receive test failures, corrections, and follow-up tasks just like a continuing agent thread.

## Enable a project

When the user sends `dsbro` as a standalone command:

1. Locate the project-root `AGENTS.md`, creating it if absent.
2. Add or replace exactly one managed block:

```markdown
<!-- dsbro:start -->
## dsbro

Use `$codex-deepseek-worker:deepseek-worker` as the default worker for implementation and debugging. The parent Codex agent delegates work to a DeepSeek V4 Flash Codex thread, reviews the actual diff, and runs relevant verification.

Keep routine delegation silent. Report actual changes, verification, blockers, and risks; do not recite the workflow unless asked.
<!-- dsbro:end -->
```

3. Remove obsolete dsbro managed blocks. Remove `.codex/agents/worker.toml` only when its content identifies it as the old dsbro-generated DeepSeek worker; preserve any user-authored worker.
4. Preserve unrelated `AGENTS.md` content.
5. Reply only `dsbro enabled.` unless a concrete task was also supplied.

## Start a worker thread

Resolve the Codex home as `$env:CODEX_HOME` when set, otherwise `%USERPROFILE%\.codex`, and use its `dsbro-models.json` file. Call the bundled `dsbro` MCP server's `codex` tool with the task, project root, and these required arguments:

```json
{
  "model": "deepseek-v4-flash",
  "sandbox": "danger-full-access",
  "approval-policy": "never",
  "config": {
    "model_provider": "deepseek",
    "model_catalog_json": "<resolved Codex home>/dsbro-models.json",
    "model_providers.deepseek.name": "deepseek",
    "model_providers.deepseek.base_url": "https://api.deepseek.com/",
    "model_providers.deepseek.wire_api": "responses",
    "model_providers.deepseek.env_key": "DEEPSEEK_API_KEY"
  }
}
```

Do not omit or replace these model and provider values. The official MCP tool rebuilds its Codex configuration for each new thread, so server-launch configuration alone does not select the worker provider. The tool starts a persistent Codex conversation and returns its thread identifier.

Do not invoke `codex exec`, `codex app-server`, the DeepSeek API, or a custom process manager. The bundled server directly launches the official `codex mcp-server`; the tool call supplies its native configuration overrides for the DeepSeek provider.

## Wait for the worker

- If Code Mode yields while the MCP call is still running, wait for that same call instead of terminating it or taking over the delegated work. The bundled server's native one-hour tool timeout remains the upper bound.
- After the call completes or fails, the parent resumes its normal review and verification role.

## Continue the same worker

Send test failures, review comments, or the next instruction through the bundled server's `codex-reply` tool using the thread identifier returned by `codex`.

Start separate worker threads when normal Codex orchestration would use separate subagents. Do not overlap write scopes. After worker changes, the parent inspects the real diff and independently verifies the result. Keep API keys out of prompts, files, logs, and responses.

Current Codex 0.146.1 rejects third-party models inside the built-in `spawn_agent` router. Therefore dsbro uses Codex's own documented MCP-server worker surface rather than silently falling back to an OpenAI worker. Codex owns the worker thread, persistence, tools, sandbox, and follow-up turns.

## Update dsbro

When the user sends `update_dsbro` as a standalone command:

1. Use `%LOCALAPPDATA%\Codex\marketplaces\codex-deepseek-worker`.
2. If absent, clone `https://github.com/mandgrapes/codex-deepseek-worker.git` there. If present, verify its origin and pull with `--ff-only`.
3. Run its `install.ps1`. It preserves the API key and refreshes the provider, official Flash model metadata, launcher, and plugin.
4. Verify `codex-deepseek-worker@codex-deepseek-worker` is installed and enabled.
5. Report the installed version and ask the user to restart Codex and open a new thread.

## Configuration

- Model: `deepseek-v4-flash` only.
- Protocol: Responses API.
- Credential: `DEEPSEEK_API_KEY` from the Windows user environment.
- Model catalog: `~/.codex/dsbro-models.json` from DeepSeek's official Codex setup.
- Worker sandbox: `danger-full-access` to avoid the native Windows sandbox helper. The parent Codex sandbox is unchanged.
- The parent Codex model/provider is unchanged.
