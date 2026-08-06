# dsbro

Run OpenAI Codex and DeepSeek V4 Flash separately on Windows:

```powershell
codex   # OpenAI Codex
ds      # DeepSeek V4 Flash
```

## Install

Install the Codex CLI first, then run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/mandgrapes/codex-deepseek-worker/main/install.ps1 | iex
```

Open a new PowerShell window and run `ds`. Enter your DeepSeek API key when prompted.

## Commands

```powershell
ds             # Start Codex with DeepSeek
codex          # Start Codex with OpenAI
set_ds_key     # Replace the DeepSeek API key
update_ds      # Update dsbro
```

Codex arguments work with `ds`:

```powershell
ds -s workspace-write
ds exec "inspect this project and fix the tests"
```

## Notes

- `ds` and `codex` share the configuration, skills, and sandbox in `~/.codex`.
- Their chat sessions remain separate. Do not resume one provider's session with the other.
- DeepSeek receives prompts, file contents, and tool results used in its session.
- The API key is stored in the Windows user environment variable `DEEPSEEK_API_KEY`, not in this repository.
