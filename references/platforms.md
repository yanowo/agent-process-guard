# Platform notes

## Common Agent Skills format

This skill uses only the common Agent Skills structure:

```text
process-guard/
  SKILL.md
  scripts/
  references/
```

The same folder can be copied to both Codex and Claude Code skill directories.

## Codex

Codex discovers skills from `.agents/skills/` in the repository path and from `$HOME/.agents/skills/` for user-level skills.

Recommended locations:

```text
$HOME/.agents/skills/process-guard/SKILL.md
.agents/skills/process-guard/SKILL.md
```

For stronger default behavior, paste `references/AGENTS.md.snippet` into `~/.codex/AGENTS.md` or a repository-level `AGENTS.md`.

Codex examples should resolve the script directory from installed skill locations unless the skill path is already visible in context.

## Claude Code

Claude Code discovers skills from `$HOME/.claude/skills/` and `.claude/skills/`.

Recommended locations:

```text
$HOME/.claude/skills/process-guard/SKILL.md
.claude/skills/process-guard/SKILL.md
```

When a Claude Code skill runs, prefer the platform-provided skill directory variable when available:

```bash
$CLAUDE_SKILL_DIR/scripts/status-managed-processes.sh
```

For stronger default behavior, paste `references/CLAUDE.md.snippet` into `~/.claude/CLAUDE.md` or a repository-level `CLAUDE.md`.

Claude Code hooks can enforce this policy more strictly, but hooks are intentionally optional so the skill remains portable.

## Run directory

The default run directory is `.agent-run/`, not `.codex-run/` or `.claude-run/`, so both tools share the same process state format.

Override when needed:

```bash
PROCESS_GUARD_RUN_DIR=.codex-run "$PROCESS_GUARD_DIR/scripts/status-managed-processes.sh"
```

```powershell
$env:PROCESS_GUARD_RUN_DIR = ".codex-run"
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/status-managed-processes.ps1"
```
