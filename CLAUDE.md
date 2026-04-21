# Claude Code — use AGENTS.md

All repository rules for contributors and AI agents are defined in **`AGENTS.md`** at the root of this repo (safety, prohibited commands, filesystem boundaries, shell/tooling policy, build and test workflow, SwiftUI guidance).

**Read and follow `AGENTS.md` before substantial work.** Do not contradict it. Put any Claude-only preferences here only if they truly cannot live in `AGENTS.md`; keep them minimal.

**Codex** uses the same `AGENTS.md` directly. **Cursor** is wired via `.cursor/rules/agents-md-authority.mdc` to honor `AGENTS.md`.
