# process-guard

語言： [English](README.md) | 繁體中文 | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

給 Codex 與 Claude Code 共用的跨代理終端機程序管理技能。

`process-guard` 用來避免 coding agent 卡在長時間執行的指令上，也避免留下孤兒程序，例如開發伺服器、worker、indexer、bot、daemon、shell、前景執行的 Docker 程序與 watch 模式。

## 功能

- 在執行前將指令分類為有限一次性、長時間執行或互動式指令。
- 透過 guarded wrapper 與明確 timeout 執行有限指令。
- 將長時間執行的指令啟動為受管理背景程序。
- 在 `.agent-run/` 下追蹤 PID、metadata 與 log。
- 使用 health URL、TCP port、自訂 probe 或 log pattern 檢查 readiness。
- 遞迴停止受管理程序，而不是只殺掉父程序 PID。

## 安裝

安裝到使用者層級，同時給 Codex 與 Claude Code 使用：

```bash
./scripts/install.sh --target both --scope user
```

安裝到專案層級，同時給兩個工具使用：

```bash
./scripts/install.sh --target both --scope project
```

PowerShell：

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

手動安裝位置：

```text
Codex user:       ~/.agents/skills/process-guard/
Codex repo:       .agents/skills/process-guard/
Claude Code user: ~/.claude/skills/process-guard/
Claude Code repo: .claude/skills/process-guard/
```

## 快速使用

用 timeout 執行有限指令：

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

啟動暫時性的開發伺服器、檢查回應，並在結束時自動停止：

```bash
"$PROCESS_GUARD_DIR/scripts/with-managed-process.sh" \
  --name web \
  --command "pnpm dev --host 127.0.0.1 --port 3000" \
  --port 3000 \
  --timeout 60 \
  -- \
  "curl -fsS http://127.0.0.1:3000 >/dev/null"
```

PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$ProcessGuardDir/scripts/with-managed-process.ps1" `
  -Name "web" `
  -Command "pnpm dev --host 127.0.0.1 --port 3000" `
  -Port 3000 `
  -TimeoutSeconds 60 `
  -CheckCommand "Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3000 | Out-Null"
```

## 持久化指令

若要讓規則更不容易漏掉，請把對應片段貼進 agent 的持久化指令：

```text
references/AGENTS.md.snippet
references/CLAUDE.md.snippet
```

## 執行狀態

受管理程序預設會把狀態寫入 `.agent-run/`：

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

需要時可用 `PROCESS_GUARD_RUN_DIR` 覆寫。

## 文件

- [安裝指南](references/install.md)
- [範例](references/examples.md)
- [長時間執行模式](references/long-running-patterns.md)
- [平台說明](references/platforms.md)
- [疑難排解](references/troubleshooting.md)

## 授權

本專案以 [MIT License](LICENSE) 釋出。
