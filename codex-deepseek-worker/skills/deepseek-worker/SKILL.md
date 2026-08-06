---
name: deepseek-worker
description: Enable, use, or update dsbro, a Codex worker thread powered by DeepSeek V4 Flash through the Responses API. Use when the user says "dsbro", "update_dsbro", asks to use DeepSeek as a coding worker, or when a project AGENTS.md activates dsbro for implementation work.
---

# dsbro

`dsbro` runs `deepseek-v4-flash` in a normal Codex coding session. It gets the Codex agent prompt, project instructions, repository tools, patch tool, shell, sandbox, and local conversation history. The parent Codex session delegates, reviews, and accepts the work.

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

3. Remove obsolete dsbro managed blocks and `.codex/agents/worker.toml` left by the abandoned custom-agent experiment.
4. Preserve unrelated `AGENTS.md` content.
5. Reply only `dsbro enabled.` unless a concrete task was also supplied.

## Start a worker thread

Invoke the launcher from this skill directory. Pass the parent session's current sandbox mode when known:

```powershell
& ".\scripts\invoke-dsbro.ps1" -ProjectRoot "<project-root>" -Task "<task>" -SandboxMode workspace-write
```

Long tasks may use `-TaskFile`. The launcher prints `DSBRO_SESSION_ID=<uuid>`; retain that ID for follow-ups during the task.

## Continue the same worker

Send test failures, review comments, or the next instruction back to the same thread:

```powershell
& ".\scripts\invoke-dsbro.ps1" -ProjectRoot "<project-root>" -SessionId "<uuid>" -Task "<follow-up>"
```

Start separate worker threads when normal Codex orchestration would use separate subagents. Do not overlap write scopes. After worker changes, the parent inspects the real diff and independently verifies the result. Keep API keys out of prompts, files, logs, and responses.

Current Codex 0.146.1 rejects third-party models inside the built-in `spawn_agent` router. Therefore the launcher uses a child Codex thread rather than silently falling back to an OpenAI worker. Apart from that router boundary, the worker uses the Codex runtime and model metadata directly.

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
- The parent Codex model/provider is unchanged.
