# dsbro: DeepSeek Codex worker thread

## Goal

`dsbro` makes `deepseek-v4-flash` the default implementation worker for a project. The current Codex session remains the supervisor and owns review and verification.

## Architecture

1. The installer adds `[model_providers.deepseek]` using the Responses API and environment-key authentication.
2. It installs DeepSeek's official V4 Flash Codex model metadata at `~/.codex/dsbro-models.json`.
3. The plugin starts a normal persisted `codex exec` session with the DeepSeek provider and returns its session ID.
4. The worker reads and edits the project using Codex tools and the selected sandbox.
5. Follow-ups resume the same local session, preserving the worker's context.
6. The parent Codex agent reviews the real diff and independently runs tests.

## State model

DeepSeek's Responses API is stateless on the server: it does not support `previous_response_id` or a hosted conversation object. Codex provides the state by storing its thread locally and replaying the required history when the session is resumed. The worker is therefore persistent from the user's and parent's perspective.

## Built-in router boundary

Codex 0.146.1 validates `spawn_agent` models against an OpenAI allowlist and rejects `deepseek-v4-flash`, even from a custom-agent TOML. dsbro uses a child Codex thread to avoid fallback while retaining Codex tools, prompts, context, session history, and sandboxing.

## Constraints

- DeepSeek model: `deepseek-v4-flash`.
- Main Codex model/provider: unchanged.
- API key: Windows user environment, never Git or TOML.
- Communication: routine handoffs stay quiet.

## Removed routes

- No Chat Completions patch wrapper.
- No selected-snippet request serialization.
- No ephemeral-only lifecycle.
- No custom-agent configuration that silently falls back to an OpenAI worker.

## Commands

- `dsbro`: persist project activation in `AGENTS.md`.
- `update_dsbro`: pull, reinstall, and refresh local configuration.
