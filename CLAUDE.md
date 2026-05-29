# acc-evm-wal — Claude's working notes

A content plugin for the [Agentic Community College (ACC)](https://github.com/alilloig/agentic-community-college) framework. **No runtime code here** — the framework owns that.

## What you can do here

- **Author a new lesson** — don't write files by hand. Invoke ACC's `lesson-creator` skill and point it at this repo + a reference codebase. The skill emits the entire `lessons/<slug>/` tree.
- **Refine an existing lesson** — edit `lessons/<slug>/{lesson.json, sections.json, sections/*.md, artifact/template.html, tests/}` directly. Re-run the lesson-creator's validation pass after edits to confirm the prompts still produce passing tests in both output modes.
- **Add or refine a probe** — edit `accContent.probes` in `.claude-plugin/plugin.json`. Four kinds are supported: `filesystem-exists`, `http-get`, `shell-exit-zero`, `claude-plugin-enabled`. The full shape lives in ACC's `mcp/server/src/schemas/courseProbes.ts`.

## What NOT to do here

- Don't add MCP server code, agents, or framework skills. Those live in `agentic-community-college`.
- Don't add top-level `agents/` or `skills/` directories, and don't expand `commands/` beyond the `start.md` entrypoint — this is content-only. Including those would make ACC's discovery treat the manifest as a regular plugin instead of a course plugin.

## Probe declaration cheat sheet

Each entry under `accContent.probes` is one prerequisite check. Common shape:

```json
{
  "id": "kebab-case-id",
  "kind": "shell-exit-zero",
  "message_pass": "Tool installed.",
  "message_fail": "Install <tool> from <url>.",
  "params": { "command": "tool", "args": ["--version"] },
  "remediation": {
    "kind": "shell",
    "command": "brew install tool",
    "timeout_ms": 60000
  }
}
```

Probe IDs are unique within this course. Lessons reference them by id in their `lesson.json:prerequisites`; the conductor runs each via `runPreflightProbe` between `selectLesson` and `setPersonalization`.

## How a session runs (end-to-end)

1. User runs `/agentic-community-college:start` from their `projectRoot`.
2. ACC's `course-engine` skill calls `start` → discovers this plugin via `~/.claude/plugins/installed_plugins.json`, validates every lesson manifest pair + the probes block, and renders the catalog.
3. User picks a namespaced slug → `selectLesson` mints v4 state, seeds the workspace.
4. If the picked lesson has prerequisites, the conductor runs them via `runPreflightProbe` — passing each, asking the user before triggering any remediation.
5. User picks `learning` or `explanatory` → `setOutputMode`.
6. User answers personalization → `setPersonalization`.
7. `course-conductor` agent loops: `advanceArtifact` → `nextSection` → edits → `verifySection` → repeat.

## Course-specific notes

This course covers Walrus + Solidity. Helpful references when authoring lessons here:

- **Walrus docs**: https://docs.wal.app — focus on the HTTP API for blob upload/read and the testnet aggregator/publisher URLs.
- **Walrus testnet aggregator** (off-chain read): `https://aggregator.walrus-testnet.walrus.space`
- **Walrus testnet publisher** (off-chain write): `https://publisher.walrus-testnet.walrus.space`
- **Foundry book** for the Solidity side: https://book.getfoundry.sh
- The on-chain integration pattern is small: a Solidity contract stores a `bytes32` (or `string`) blob ID, and the dApp's frontend fetches the actual content from a Walrus aggregator using that ID. Keep lesson scope tight around that pattern — don't pull in full Sui Move concepts.
