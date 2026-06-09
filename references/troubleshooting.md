# Troubleshooting

All Bash examples assume `PROCESS_GUARD_DIR` is already resolved as described in `SKILL.md`.
All PowerShell examples assume `$ProcessGuardDir` is already resolved as described in `SKILL.md`.

## Check managed process status

Bash:

```bash
"$PROCESS_GUARD_DIR/scripts/status-managed-processes.sh"
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/status-managed-processes.ps1"
```

## Clean all managed processes

Bash:

```bash
"$PROCESS_GUARD_DIR/scripts/cleanup-managed-processes.sh"
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/cleanup-managed-processes.ps1"
```

## View logs

Bash:

```bash
tail -120 .agent-run/logs/<name>.log
```

PowerShell:

```powershell
Get-Content .agent-run/logs/<name>.out.log -Tail 120
Get-Content .agent-run/logs/<name>.err.log -Tail 120
```

## Port already in use

The start script refuses to kill processes it did not start.

Options:

1. choose another port
2. stop the process manually after identifying it
3. ask the user before killing unrelated processes

Linux/macOS:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

Windows PowerShell:

```powershell
Get-NetTCPConnection -LocalPort 3000 -State Listen | Select-Object LocalAddress,LocalPort,OwningProcess
```

## Process exits before readiness

Inspect the log:

```bash
tail -120 .agent-run/logs/<name>.log
```

Common causes:

- missing environment variables
- dependency install not completed
- wrong working directory
- port conflict
- database not running
- health URL path does not exist

Use `--cwd` when the process must start from a specific directory.

## Readiness never succeeds

Use the strongest available readiness check:

- HTTP app: `--health-url`
- TCP app: `--port`
- worker/indexer/bot: `--ready-log-pattern`
- complex readiness: `--ready-command`

Example:

```bash
"$PROCESS_GUARD_DIR/scripts/start-managed-process.sh" \
  --name indexer \
  --command "python indexer.py" \
  --ready-command "grep -q 'synced' .agent-run/logs/indexer.log" \
  --timeout 120
```

## Cleanup appears incomplete

Run:

```bash
"$PROCESS_GUARD_DIR/scripts/status-managed-processes.sh"
"$PROCESS_GUARD_DIR/scripts/cleanup-managed-processes.sh"
```

Do not use broad commands like `killall node` or `pkill python` unless the user explicitly approves and you know the machine has no unrelated workloads.
