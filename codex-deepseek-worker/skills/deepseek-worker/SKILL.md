---
name: deepseek-worker
description: Delegate implementation work to DeepSeek V4 Flash through an OpenAI-compatible Chat Completions API, then have Codex review, apply, and test the returned patch. Use when the user says "dsbro" (case-insensitive), says "update_dsbro" to update this plugin, uses the legacy phrase "用 DeepSeek 当小弟", asks to enable DeepSeek as the default worker for a project, explicitly requests DeepSeek delegation, or when a project AGENTS.md activates this skill for implementation tasks.
---

# DeepSeek Worker

Use DeepSeek only as a remote implementation worker. Codex retains local repository access, chooses the context sent to the API, and owns acceptance.

## Enable project mode

When the user sends `dsbro` as a standalone command (case-insensitive), or uses the legacy phrase `用 DeepSeek 当小弟`, without a task:

1. Find the applicable project-root `AGENTS.md`, or create it if absent.
2. Add or update exactly one managed block:

```markdown
<!-- codex-deepseek-worker:start -->
## DeepSeek worker

Use `$codex-deepseek-worker:deepseek-worker` by default for implementation tasks. DeepSeek receives only the context Codex explicitly sends. Codex must review any returned patch and run relevant verification before reporting success.
Keep routine delegation silent. Report actual progress, changes, tests, blockers, and risks; do not narrate the DeepSeek handoff or recite this workflow unless the user asks.
<!-- codex-deepseek-worker:end -->
```

3. Preserve all unrelated `AGENTS.md` content.
4. Reply only `dsbro enabled.` and stop unless the user also gave a concrete task.

## Update the plugin

When the user sends `update_dsbro` as a standalone command (case-insensitive):

1. Use the standard repository path `%LOCALAPPDATA%\Codex\marketplaces\codex-deepseek-worker`.
2. If it already exists, verify that it is a Git repository whose `origin` points to `mandgrapes/codex-deepseek-worker`. Do not update or delete an unrelated directory.
3. If it is absent, clone the public repository `https://github.com/mandgrapes/codex-deepseek-worker.git` to that path with Git. No GitHub login is required.
4. Run the repository's `install.ps1`. It pulls with `--ff-only`, refreshes the marketplace registration, and reinstalls the plugin. An existing `DEEPSEEK_WORKER_API_KEY` is preserved without being displayed or overwritten.
5. Verify with `codex plugin list` that `codex-deepseek-worker` is `installed, enabled`.
6. Report the installed version and ask the user to restart Codex and open a new thread. Do not perform project implementation work in the update turn unless separately requested.

## Delegate a task

### Communication

- Do not announce that the task will be sent to DeepSeek.
- Do not recite the sequence of reading context, requesting a patch, reviewing it, and running tests.
- If a host policy requires an intermediate update before tool use, keep it neutral and short, such as `Working on it.`
- Report only information useful to the user: material progress, required approvals, blockers, rejected unsafe or incorrect output, actual changes, verification results, and remaining risks.
- Do not mention DeepSeek in the final answer unless its failure or rejected output materially affected the result, or the user asks about delegation details.

1. Inspect the repository and define a bounded implementation task.
2. Select enough file content, interfaces, constraints, and test expectations for the task. Do not give DeepSeek file paths to read; include actual selected content in the request JSON.
3. Create temporary input and output JSON files outside the repository when possible.
4. Use this input shape:

```json
{
  "task": "Implement the requested change",
  "constraints": ["Preserve the public API"],
  "context": [
    {"path": "src/example.ts", "content": "selected file content"}
  ],
  "test_expectations": ["npm test"]
}
```

5. Invoke the bundled script:

```powershell
& "<skill-directory>\scripts\invoke-deepseek.ps1" -InputFile "<input.json>" -OutputFile "<output.json>"
```

6. Read the structured result: `summary`, `patch`, `suggested_tests`, and `risks`.
7. Inspect the patch. Use `git apply --check` when appropriate; never apply blindly.
8. Apply the accepted change, adapting manually if the patch is useful but does not apply cleanly.
9. Run relevant tests, lint, type checks, or project verification.
10. If verification fails, send only the necessary updated context and failure details for at most two repair attempts.
11. Report the actual diff and verification result. Do not treat DeepSeek's summary as proof.

## Boundaries

- DeepSeek cannot browse the repository or execute local tools through this integration.
- Only content placed in the request JSON is sent to the configured provider.
- The script writes only the requested response JSON and never applies patches.
- Codex may decide how much context the task needs; do not impose additional file-type or directory restrictions unless the user or repository rules require them.
- Keep API credentials out of prompts, files, logs, and final responses.
- If configuration or the API call fails, leave the repository unchanged and report the failure.

## Configuration

Read settings first from process environment variables, then from Windows user environment variables:

- `DEEPSEEK_WORKER_API_KEY` (required)
- `DEEPSEEK_WORKER_BASE_URL` (default `https://api.deepseek.com`)
- `DEEPSEEK_WORKER_MODEL` (default `deepseek-v4-flash`)

The endpoint must support OpenAI-compatible `/chat/completions`.
