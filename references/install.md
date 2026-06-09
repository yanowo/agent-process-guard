# Install process-guard skill

`process-guard` is a single Agent Skills folder that can be installed for Codex, Claude Code, or both.

## Folder name

Install the folder as:

```text
process-guard
```

The folder must contain:

```text
process-guard/
  SKILL.md
  scripts/
  references/
```

## Codex user-level install

Use this when you want Codex to apply process hygiene across all repositories.

```bash
mkdir -p ~/.agents/skills
cp -R agent-process-guard ~/.agents/skills/process-guard
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.agents\skills" | Out-Null
Copy-Item -Recurse .\agent-process-guard "$HOME\.agents\skills\process-guard"
```

## Codex repository-level install

Use this when you want the rule to travel with a repo.

```bash
mkdir -p .agents/skills
cp -R agent-process-guard .agents/skills/process-guard
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force ".agents\skills" | Out-Null
Copy-Item -Recurse .\agent-process-guard ".agents\skills\process-guard"
```

## Claude Code user-level install

Use this when you want Claude Code to apply process hygiene across all repositories.

```bash
mkdir -p ~/.claude/skills
cp -R agent-process-guard ~/.claude/skills/process-guard
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse .\agent-process-guard "$HOME\.claude\skills\process-guard"
```

## Claude Code repository-level install

Use this when you want the rule to travel with a repo.

```bash
mkdir -p .claude/skills
cp -R agent-process-guard .claude/skills/process-guard
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force ".claude\skills" | Out-Null
Copy-Item -Recurse .\agent-process-guard ".claude\skills\process-guard"
```

## Install using the bundled script

Linux/macOS:

```bash
./scripts/install.sh --target both --scope user
./scripts/install.sh --target both --scope project
```

Windows PowerShell:

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

## Manual install to both tools

User-level, Linux/macOS:

```bash
mkdir -p ~/.agents/skills ~/.claude/skills
cp -R agent-process-guard ~/.agents/skills/process-guard
cp -R agent-process-guard ~/.claude/skills/process-guard
```

Repository-level:

```bash
mkdir -p .agents/skills .claude/skills
cp -R agent-process-guard .agents/skills/process-guard
cp -R agent-process-guard .claude/skills/process-guard
```

## Optional persistent rules

Skills load when selected by the agent. To make process hygiene harder to miss, also add persistent instructions.

For Codex, paste this into either:

- `~/.codex/AGENTS.md`
- repo `AGENTS.md`

```text
references/AGENTS.md.snippet
```

For Claude Code, paste this into either:

- `~/.claude/CLAUDE.md`
- repo `CLAUDE.md`

```text
references/CLAUDE.md.snippet
```

## Smoke test prompt

Run this in Codex or Claude Code:

```text
Use the process-guard skill. Start a local HTTP server, check that it responds, then stop every process you started before the final response.
```

Expected behavior:

- server starts through `start-managed-process` or `with-managed-process`
- logs appear under `.agent-run/logs/`
- PID files appear under `.agent-run/pids/`
- final response says the process was stopped
- `status-managed-processes` reports no managed processes remaining
