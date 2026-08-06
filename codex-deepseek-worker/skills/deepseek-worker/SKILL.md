---
name: deepseek-worker
description: Enable or update dsbro, a project-scoped native Codex worker powered by DeepSeek V4 Flash through the Responses API. Use when the user says "dsbro", "update_dsbro", asks to use DeepSeek as a Codex sub-agent, or when a project AGENTS.md activates dsbro for implementation work.
---

# dsbro

`dsbro` is native Codex multi-agent orchestration. The parent Codex agent remains in charge. A project-scoped custom agent named `worker` uses `deepseek-v4-flash` through DeepSeek's Responses API and works with Codex's normal repository tools and inherited sandbox.

## Enable a project

When the user sends `dsbro` as a standalone command:

1. Locate the project root.
2. Create `.codex/agents/` if needed.
3. Copy `../../assets/worker.toml` from this skill's directory to `.codex/agents/worker.toml`, replacing an older dsbro worker file.
4. Add or replace exactly one managed block in the project-root `AGENTS.md`:

```markdown
<!-- dsbro:start -->
## dsbro

For implementation and debugging work, delegate a well-bounded task to the `worker` sub-agent by default. The worker is project-configured to use DeepSeek V4 Flash. The parent Codex agent must review the resulting diff and run relevant tests before reporting success.

Keep delegation silent. Report only useful progress, actual changes, verification results, blockers, and risks. Do not recite the delegation workflow unless asked.
<!-- dsbro:end -->
```

5. Remove the obsolete `codex-deepseek-worker` managed block if present.
6. Preserve unrelated `AGENTS.md` content.
7. Reply only `dsbro enabled.` unless a concrete task was also supplied.

Project custom-agent files are loaded at session start. If dsbro was just enabled, tell the user to open a new Codex thread before expecting the DeepSeek worker to be selected.

## Work in an enabled project

- Use Codex's native sub-agent mechanism and select the project custom agent named `worker` for bounded implementation or debugging tasks.
- Give the worker a clear objective, acceptance criteria, and relevant constraints. It can inspect the repository and use local tools itself; do not serialize source files into an API request.
- The parent Codex agent owns architectural decisions, reviews all changes, runs appropriate verification, and fixes or rejects weak output.
- Parallel workers are optional. Avoid overlapping write scopes.
- Keep routine handoff narration silent.
- Never expose API keys in prompts, logs, files, or responses.

## Update dsbro

When the user sends `update_dsbro` as a standalone command:

1. Use `%LOCALAPPDATA%\Codex\marketplaces\codex-deepseek-worker`.
2. If absent, clone `https://github.com/mandgrapes/codex-deepseek-worker.git` there. If present, verify its origin matches that repository and pull with `--ff-only`.
3. Run its `install.ps1`. The installer preserves an existing API key and refreshes the native provider, model catalog, plugin, and worker template.
4. Verify the plugin is installed and enabled.
5. Report the installed version and ask the user to restart Codex and open a new thread.

## Configuration contract

The installer owns these local pieces:

- `DEEPSEEK_API_KEY` in the Windows user environment.
- A managed `[model_providers.deepseek]` block in `~/.codex/config.toml` using `wire_api = "responses"` and `env_key = "DEEPSEEK_API_KEY"`.
- `~/.codex/dsbro-models.json`, containing only `deepseek-v4-flash` metadata.

The parent session's default model and provider are deliberately left unchanged.
