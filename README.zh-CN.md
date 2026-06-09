# process-guard

语言： [English](README.md) | [繁體中文](README.zh-TW.md) | 简体中文 | [日本語](README.ja.md) | [한국어](README.ko.md)

给 Codex 与 Claude Code 共用的跨代理终端进程管理技能。

`process-guard` 用来避免 coding agent 卡在长时间运行的命令上，也避免留下孤儿进程，例如开发服务器、worker、indexer、bot、daemon、shell、前景运行的 Docker 进程与 watch 模式。

## 功能

- 在执行前将命令分类为有限一次性、长时间运行或交互式命令。
- 通过 guarded wrapper 与明确 timeout 执行有限命令。
- 将长时间运行的命令启动为受管理后台进程。
- 在 `.agent-run/` 下跟踪 PID、metadata 与 log。
- 使用 health URL、TCP port、自定义 probe 或 log pattern 检查 readiness。
- 递归停止受管理进程，而不是只杀掉父进程 PID。

## 安装

安装到用户级别，同时给 Codex 与 Claude Code 使用：

```bash
./scripts/install.sh --target both --scope user
```

安装到项目级别，同时给两个工具使用：

```bash
./scripts/install.sh --target both --scope project
```

PowerShell：

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

手动安装位置：

```text
Codex user:       ~/.agents/skills/process-guard/
Codex repo:       .agents/skills/process-guard/
Claude Code user: ~/.claude/skills/process-guard/
Claude Code repo: .claude/skills/process-guard/
```

## 快速使用

用 timeout 执行有限命令：

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

启动临时开发服务器、检查响应，并在结束时自动停止：

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

若要让规则更不容易遗漏，请把对应片段贴进 agent 的持久化指令：

```text
references/AGENTS.md.snippet
references/CLAUDE.md.snippet
```

## 执行状态

受管理进程默认会把状态写入 `.agent-run/`：

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

需要时可用 `PROCESS_GUARD_RUN_DIR` 覆盖。

## 文档

- [安装指南](references/install.md)
- [示例](references/examples.md)
- [长时间运行模式](references/long-running-patterns.md)
- [平台说明](references/platforms.md)
- [故障排查](references/troubleshooting.md)

## 授权

本项目以 [MIT License](LICENSE) 发布。
