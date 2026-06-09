# Examples

All Bash examples assume `PROCESS_GUARD_DIR` is already resolved as described in `SKILL.md`.
All PowerShell examples assume `$ProcessGuardDir` is already resolved as described in `SKILL.md`.

## Resolve process-guard directory

Bash:

```bash
PROCESS_GUARD_DIR="${CLAUDE_SKILL_DIR:-}"
if [ -z "$PROCESS_GUARD_DIR" ]; then
  for d in .agents/skills/process-guard .claude/skills/process-guard "$HOME/.agents/skills/process-guard" "$HOME/.claude/skills/process-guard"; do
    [ -f "$d/SKILL.md" ] && PROCESS_GUARD_DIR="$d" && break
  done
fi
[ -n "$PROCESS_GUARD_DIR" ] || { echo "process-guard not found" >&2; exit 1; }
```

PowerShell:

```powershell
$ProcessGuardDir = $env:CLAUDE_SKILL_DIR
if (-not $ProcessGuardDir) {
  foreach ($candidate in @(".agents/skills/process-guard", ".claude/skills/process-guard", "$HOME/.agents/skills/process-guard", "$HOME/.claude/skills/process-guard")) {
    if (Test-Path (Join-Path $candidate "SKILL.md")) { $ProcessGuardDir = $candidate; break }
  }
}
if (-not $ProcessGuardDir) { throw "process-guard not found" }
```

## Node / Next.js

```bash
"$PROCESS_GUARD_DIR/scripts/with-managed-process.sh" \
  --name next-web \
  --command "pnpm dev --host 127.0.0.1 --port 3000" \
  --port 3000 \
  --timeout 60 \
  -- \
  "curl -fsS http://127.0.0.1:3000 >/dev/null"
```

## Python / FastAPI

```bash
"$PROCESS_GUARD_DIR/scripts/with-managed-process.sh" \
  --name fastapi \
  --command "uvicorn app.main:app --host 127.0.0.1 --port 8000" \
  --health-url "http://127.0.0.1:8000/health" \
  --timeout 60 \
  -- \
  "curl -fsS http://127.0.0.1:8000/health >/dev/null"
```

## Python worker without a port

```bash
"$PROCESS_GUARD_DIR/scripts/start-managed-process.sh" \
  --name worker \
  --command "python worker.py" \
  --ready-log-pattern "ready|started|connected" \
  --timeout 60

"$PROCESS_GUARD_DIR/scripts/status-managed-processes.sh"
"$PROCESS_GUARD_DIR/scripts/stop-managed-process.sh" --name worker
```

## Rust server

```bash
"$PROCESS_GUARD_DIR/scripts/with-managed-process.sh" \
  --name rust-api \
  --command "cargo run --bin api" \
  --port 8080 \
  --timeout 120 \
  -- \
  "curl -fsS http://127.0.0.1:8080/health >/dev/null"
```

## Go indexer without a port

```bash
"$PROCESS_GUARD_DIR/scripts/start-managed-process.sh" \
  --name go-indexer \
  --command "go run ./cmd/indexer" \
  --ready-log-pattern "synced|ready|started|connected" \
  --timeout 120

"$PROCESS_GUARD_DIR/scripts/stop-managed-process.sh" --name go-indexer
```

## Docker Compose

Prefer detached mode when containers intentionally need to run during checks:

```bash
docker compose up -d
# run finite checks here
docker compose down
```

Do not use unmanaged foreground mode:

```bash
docker compose up
```

## Finite command with timeout

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 180 -- pnpm test
```

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 300 -- cargo test
```

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- go test ./...
```

## PowerShell example

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/with-managed-process.ps1" `
  -Name "web" `
  -Command "pnpm dev --host 127.0.0.1 --port 3000" `
  -Port 3000 `
  -TimeoutSeconds 60 `
  -CheckCommand "Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3000 | Out-Null"
```
