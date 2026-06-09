# process-guard

언어: [English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | 한국어

Codex와 Claude Code에서 함께 사용할 수 있는 크로스 에이전트 터미널 프로세스 관리 스킬입니다.

`process-guard`는 coding agent가 오래 실행되는 명령에서 멈춰 있거나, 개발 서버, worker, indexer, bot, daemon, shell, 포그라운드 Docker 프로세스, watch 모드 같은 고아 프로세스를 남기는 일을 줄여 줍니다.

## 기능

- 실행 전에 명령을 유한한 일회성 명령, 장시간 실행 명령, 대화형 명령으로 분류합니다.
- 유한 명령을 guarded wrapper와 명시적인 timeout으로 실행합니다.
- 장시간 실행 명령을 관리되는 백그라운드 프로세스로 시작합니다.
- `.agent-run/` 아래에 PID, metadata, log를 기록합니다.
- health URL, TCP port, 사용자 정의 probe, log pattern으로 readiness를 확인합니다.
- 부모 PID만 종료하지 않고 관리 대상 프로세스를 재귀적으로 중지합니다.

## 설치

사용자 범위에 설치해 Codex와 Claude Code에서 모두 사용:

```bash
./scripts/install.sh --target both --scope user
```

리포지토리 범위에 설치해 두 도구에서 모두 사용:

```bash
./scripts/install.sh --target both --scope project
```

PowerShell:

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

수동 설치 위치:

```text
Codex user:       ~/.agents/skills/process-guard/
Codex repo:       .agents/skills/process-guard/
Claude Code user: ~/.claude/skills/process-guard/
Claude Code repo: .claude/skills/process-guard/
```

## 빠른 사용

timeout을 지정해 유한 명령을 실행:

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

임시 개발 서버를 시작하고 응답을 확인한 뒤 자동으로 중지:

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

## 지속 지침

더 엄격하게 적용하려면 해당 snippet을 agent의 지속 지침에 붙여 넣으세요.

```text
references/AGENTS.md.snippet
references/CLAUDE.md.snippet
```

## 실행 상태

관리 대상 프로세스의 상태는 기본적으로 `.agent-run/`에 기록됩니다.

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

필요하면 `PROCESS_GUARD_RUN_DIR`로 덮어쓸 수 있습니다.

## 문서

- [설치 가이드](references/install.md)
- [예시](references/examples.md)
- [장시간 실행 패턴](references/long-running-patterns.md)
- [플랫폼 참고](references/platforms.md)
- [문제 해결](references/troubleshooting.md)

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다.
