---
name: process-guard
description: Cross-agent terminal process hygiene for Codex and Claude Code. Use before running terminal commands that may open shells, dev servers, watchers, workers, bots, miners, indexers, daemons, Docker/Kubernetes foreground processes, or any Node/Python/Rust/Go/Java/PHP/.NET command whose normal success state is to remain alive. Enforces bounded execution, managed background processes, PID/process-group tracking, log capture, readiness checks, status reporting, and cleanup.
---

# Process Guard

## Goal

Prevent Codex, Claude Code, and other Agent Skills-compatible coding agents from blocking on long-running terminal commands or leaving orphaned processes after a task.

This skill turns terminal execution into a lifecycle:

1. classify the command
2. run finite commands with a timeout
3. start long-running commands as managed background processes
4. verify readiness using a health URL, TCP port, custom probe, or log pattern
5. run task-specific checks
6. stop every process started during the task
7. report terminal hygiene in the final response

## Platform compatibility

This skill is intentionally limited to the Agent Skills common denominator:

- required `SKILL.md` with YAML frontmatter
- optional `scripts/` utilities
- optional `references/` documentation
- no mandatory Claude-only `allowed-tools`
- no mandatory Codex-only configuration

Install the same folder into either or both locations:

- Codex user scope: `$HOME/.agents/skills/process-guard/`
- Codex repo scope: `.agents/skills/process-guard/`
- Claude Code user scope: `$HOME/.claude/skills/process-guard/`
- Claude Code repo scope: `.claude/skills/process-guard/`

For strict enforcement, also paste the relevant snippet into persistent instructions:

- Codex: `references/AGENTS.md.snippet` into `~/.codex/AGENTS.md` or repo `AGENTS.md`
- Claude Code: `references/CLAUDE.md.snippet` into `~/.claude/CLAUDE.md` or repo `CLAUDE.md`

## Resolve the skill directory

Before running bundled scripts, resolve the skill directory.

Claude Code usually provides `CLAUDE_SKILL_DIR` when a skill runs. Prefer it when present.

Bash:

```bash
PROCESS_GUARD_DIR="${CLAUDE_SKILL_DIR:-}"
if [ -z "$PROCESS_GUARD_DIR" ]; then
  for d in \
    .agents/skills/process-guard \
    .claude/skills/process-guard \
    "$HOME/.agents/skills/process-guard" \
    "$HOME/.claude/skills/process-guard"; do
    if [ -f "$d/SKILL.md" ]; then PROCESS_GUARD_DIR="$d"; break; fi
  done
fi
[ -n "$PROCESS_GUARD_DIR" ] || { echo "process-guard skill directory not found" >&2; exit 1; }
```

PowerShell:

```powershell
$ProcessGuardDir = $env:CLAUDE_SKILL_DIR
if (-not $ProcessGuardDir) {
  $candidates = @(
    ".agents/skills/process-guard",
    ".claude/skills/process-guard",
    "$HOME/.agents/skills/process-guard",
    "$HOME/.claude/skills/process-guard"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path (Join-Path $candidate "SKILL.md")) { $ProcessGuardDir = $candidate; break }
  }
}
if (-not $ProcessGuardDir) { throw "process-guard skill directory not found" }
```

Use `$PROCESS_GUARD_DIR/scripts/...` or `$ProcessGuardDir/scripts/...` in examples below.

## Run directory

Managed process state is stored under `.agent-run/` by default:

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

Override with `PROCESS_GUARD_RUN_DIR` when needed:

```bash
PROCESS_GUARD_RUN_DIR=.codex-run "$PROCESS_GUARD_DIR/scripts/status-managed-processes.sh"
```

## Mandatory command classification

Before running any terminal command, classify it as one of these types.

### Finite one-shot command

A command expected to finish and return an exit code.

Examples:

```bash
npm test
pnpm build
pytest
cargo test
go test ./...
python scripts/migrate.py --dry-run
```

Run it with `scripts/guarded-run.sh` or the PowerShell equivalent.

### Long-running command

A command whose normal success state is to keep running.

Treat a command as long-running if it does any of the following:

- binds to a TCP or UDP port
- starts an HTTP, WebSocket, RPC, gRPC, Stratum, or database-like service
- watches files or hot reloads
- opens a shell, REPL, or interactive prompt
- tails or follows logs
- starts Docker/Kubernetes services in the foreground
- starts a queue worker, scheduler, daemon, subscriber, listener, miner, indexer, trading bot, crawler, poller, or stream processor
- polls external systems indefinitely
- is described by the project as `serve`, `server`, `dev`, `watch`, `reload`, `worker`, `queue`, `indexer`, `miner`, `bot`, `daemon`, `listener`, `subscriber`, `consumer`, `stream`, `scheduler`, `cron`, or `poller`

Run it with `scripts/start-managed-process.sh`, or preferably `scripts/with-managed-process.sh` when the server is only needed for one verification step.

### Interactive command

A command that expects human input or an attached terminal.

Examples:

```bash
bash
sh
zsh
powershell
pwsh
python
node
irb
rails console
psql
mysql
redis-cli
```

Do not start interactive commands unless the user explicitly requested an interactive session. Prefer a non-interactive command instead, for example `psql -c 'select 1'`.

## Prohibited unmanaged patterns

Never run these directly in the foreground in a normal agent task:

```bash
npm run dev
pnpm dev
yarn dev
next dev
vite
node server.js
python app.py
python manage.py runserver
uvicorn app:app --reload
flask run
streamlit run app.py
cargo run
cargo watch -x run
go run .
air
mvn spring-boot:run
gradle bootRun
dotnet run
dotnet watch
php artisan serve
php artisan queue:work
docker compose up
kubectl logs -f
tail -f app.log
bash
powershell
pwsh
```

This list is not exhaustive. Behavior decides classification.

## Required execution methods

### Finite commands

Use a timeout.

Bash:

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/guarded-run.ps1" -TimeoutSeconds 120 -Command "npm test"
```

### Long-running commands needed temporarily

Prefer `with-managed-process`, because it uses cleanup traps and stops the process even when the check command fails.

Bash:

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

### Long-running commands needed across multiple checks

Start, run checks, then stop.

Bash:

```bash
"$PROCESS_GUARD_DIR/scripts/start-managed-process.sh" \
  --name api \
  --command "uvicorn app.main:app --host 127.0.0.1 --port 8000" \
  --health-url "http://127.0.0.1:8000/health" \
  --timeout 60

curl -fsS http://127.0.0.1:8000/health

"$PROCESS_GUARD_DIR/scripts/stop-managed-process.sh" --name api
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/start-managed-process.ps1" `
  -Name "api" `
  -Command "uvicorn app.main:app --host 127.0.0.1 --port 8000" `
  -HealthUrl "http://127.0.0.1:8000/health" `
  -TimeoutSeconds 60

Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health | Out-Null

powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/stop-managed-process.ps1" -Name "api"
```

## Readiness policy

A process is not considered ready merely because its parent PID exists.

Use the strongest readiness signal available, in this order:

1. `--health-url` for HTTP/RPC services
2. `--port` for a TCP listener
3. `--ready-command` for a custom probe
4. `--ready-log-pattern` for programs that print known status lines

Acceptable log readiness patterns include project-specific messages such as:

```text
ready
started
listening
connected
subscribed
synced
worker started
server running
```

If no readiness check exists, inspect logs and report uncertainty. Do not claim the process is ready only because it is alive.

## Child process cleanup policy

Stopping only the parent PID is not enough. Many tools spawn child processes:

- Next.js/Vite dev servers
- Python reloaders
- Cargo watch
- Go `air`
- Docker wrappers
- test watchers

The provided scripts attempt process-group cleanup on Unix and recursive child-process cleanup on Windows. Do not replace them with `kill <pid>` unless there is no alternative.

Never use broad cleanup commands such as:

```bash
killall node
pkill python
pkill -f dev
```

They may kill user-owned processes unrelated to the current task.

## Port conflict policy

Before starting a managed process with `--port`, the script checks whether the port is already listening.

If the port is occupied by a process not tracked in `.agent-run/pids`, do not kill it automatically. Use another port or report the conflict.

## Docker and Kubernetes policy

Do not run foreground Docker/Kubernetes commands that stream forever.

Use bounded or detached equivalents:

```bash
docker compose up -d
# run checks
docker compose down
```

```bash
kubectl logs --tail=200 pod/name
# not: kubectl logs -f pod/name
```

If the user explicitly asks to leave containers running, report the project name, container names, ports, and stop command.

## Test watcher policy

Do not run watch-mode tests in agent verification.

Convert watch commands into finite commands:

```text
vitest --watch        -> vitest run
jest --watch          -> jest --runInBand
pytest-watch          -> pytest
cargo watch -x test   -> cargo test
npm run test:watch    -> inspect package scripts and choose a finite test command
```

## Final response requirement

When this skill is used, include a terminal hygiene note in the final response:

- whether a long-running process was started
- process name
- whether it was stopped
- log path
- port or health URL, if used
- any intentionally remaining process with PID and exact stop command

Do not claim cleanup succeeded unless it was actually checked with `status-managed-processes` or cleanup output.

## Quick references

- `references/install.md`: install into Codex, Claude Code, or both
- `references/AGENTS.md.snippet`: Codex persistent instruction snippet
- `references/CLAUDE.md.snippet`: Claude Code persistent instruction snippet
- `references/platforms.md`: differences between Codex and Claude Code
- `references/examples.md`: language-specific examples
- `references/long-running-patterns.md`: classification examples
- `references/troubleshooting.md`: stuck process and port conflict handling
