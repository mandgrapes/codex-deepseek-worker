# dsbro: DeepSeek Codex worker thread

## Goal

`dsbro` makes `deepseek-v4-flash` the default implementation worker for a project. The current Codex session remains the supervisor and owns review and verification.

## Architecture

1. The bundled MCP declaration starts `codex mcp-server` with the saved DeepSeek credential in its process environment; the main Codex configuration remains unchanged.
2. It installs DeepSeek's official V4 Flash Codex model metadata at `~/.codex/dsbro-models.json`.
3. The plugin bundles Codex's own `codex mcp-server`; every new worker call selects the DeepSeek model and provider through the MCP tool's native `model` and `config` arguments.
4. The worker reads and edits with Codex tools in full-access mode, avoiding the native Windows sandbox helper.
5. Codex's native `codex-reply` tool continues the same local conversation.
6. The parent Codex agent reviews the real diff and independently runs tests.

## State model

DeepSeek's Responses API is stateless on the server: it does not support `previous_response_id` or a hosted conversation object. Codex provides the state by storing its thread locally and replaying the required history when the session is resumed. The worker is therefore persistent from the user's and parent's perspective.

## Constraints

- DeepSeek model: `deepseek-v4-flash`.
- Main Codex model/provider: unchanged.
- Worker sandbox: `danger-full-access`; the main Codex sandbox is unchanged.
- API key: Windows user environment, never Git or TOML.
- Communication: routine handoffs stay quiet.

## Limitations

- Codex 0.146.1 does not accept third-party providers in built-in `spawn_agent`, so dsbro uses the official `codex mcp-server` worker surface.
- Each worker call has a Codex-native one-hour MCP timeout.

## Commands

- `dsbro`: persist project activation in `AGENTS.md`.
- `update_dsbro`: pull, reinstall, and refresh local configuration.
