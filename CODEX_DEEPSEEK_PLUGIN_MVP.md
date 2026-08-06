# dsbro v2: native DeepSeek sub-agent

## Goal

One command, `dsbro`, makes `deepseek-v4-flash` the default implementation worker for the current Codex project. Codex remains the parent agent and owns review and verification.

## Architecture

1. The installer adds a custom `deepseek` provider to the user's Codex configuration. It uses `wire_api = "responses"` and reads `DEEPSEEK_API_KEY` from the Windows user environment.
2. The installer writes `~/.codex/dsbro-models.json` with the official DeepSeek V4 Flash tool and context metadata.
3. `dsbro` copies a project custom agent to `.codex/agents/worker.toml`.
4. Codex gives custom agents precedence over built-in agents with the same name, so the project's native `worker` runs on DeepSeek.
5. The parent Codex agent delegates bounded work, reviews the actual repository diff, and runs relevant tests.

## Deliberate constraints

- Only `deepseek-v4-flash` is configured.
- The main Codex model/provider is never replaced.
- Activation is per project.
- The API key is not written to Git or TOML.
- Routine delegation is silent.

## What v1 removed

The Chat Completions wrapper, request JSON format, selected-context upload, structured patch response, and patch-application script are gone. DeepSeek now participates through Codex's own agent runtime and tools.

## Commands

- `dsbro`: enable the native worker in the current project.
- `update_dsbro`: pull, reinstall, and refresh configuration.
