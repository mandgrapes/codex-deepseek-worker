<!-- dsbro:start -->
## dsbro

Use `$codex-deepseek-worker:deepseek-worker` as the default worker for implementation and debugging. The parent Codex agent delegates work to a DeepSeek V4 Flash Codex thread, reviews the actual diff, and runs relevant verification.

Keep routine delegation silent. Report actual changes, verification, blockers, and risks; do not recite the workflow unless asked.
While the DeepSeek worker process is running, keep waiting. Latency or temporary silence is not failure and must not trigger parent takeover.
<!-- dsbro:end -->
