# process-guard

Language: English | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

Cross-agent terminal process hygiene skill for Codex and Claude Code.

`process-guard` helps coding agents avoid blocking on long-running commands and avoid leaving orphaned dev servers, workers, indexers, bots, daemons, shells, Docker foreground processes, and watchers.

## What it does

- Classifies commands as finite, long-running, or interactive before execution.
- Runs finite commands through guarded wrappers with explicit timeouts.
- Starts long-running commands as managed background processes.
- Tracks PID files, metadata, and logs under `.agent-run/`.
- Checks readiness with a health URL, TCP port, custom probe, or log pattern.
- Stops managed processes recursively instead of killing only the parent PID.

## Install

User-level install to both Codex and Claude Code:

```bash
./scripts/install.sh --target both --scope user
```

Repository-level install to both tools:

```bash
./scripts/install.sh --target both --scope project
```

PowerShell:

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

Manual locations:

```text
Codex user:       ~/.agents/skills/process-guard/
Codex repo:       .agents/skills/process-guard/
Claude Code user: ~/.claude/skills/process-guard/
Claude Code repo: .claude/skills/process-guard/
```

## Quick use

Run a finite command with a timeout:

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

Run a temporary dev server, check it, then stop it automatically:

```bash
"$PROCESS_GUARD_DIR/scripts/with-managed-process.sh" \
  --name web \
  --command "pnpm dev --host 127.0.0.1 --port 3000" \
  --port 3000 \
  --timeout 60 \
  -- \
  "curl -fsS http://127.0.0.1:3000 >/dev/null"
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/with-managed-process.ps1" `
  -Name "web" `
  -Command "pnpm dev --host 127.0.0.1 --port 3000" `
  -Port 3000 `
  -TimeoutSeconds 60 `
  -CheckCommand "Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3000 | Out-Null"
```

## Persistent instructions

For stricter enforcement, paste the relevant snippet into persistent agent instructions:

```text
references/AGENTS.md.snippet
references/CLAUDE.md.snippet
```

## Run state

Managed processes write state to `.agent-run/` by default:

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

Override it with `PROCESS_GUARD_RUN_DIR` when needed.

## Documentation

- [Install guide](references/install.md)
- [Examples](references/examples.md)
- [Long-running patterns](references/long-running-patterns.md)
- [Platform notes](references/platforms.md)
- [Troubleshooting](references/troubleshooting.md)

## License

Released under the [MIT License](LICENSE).
