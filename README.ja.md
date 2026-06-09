# process-guard

言語: [English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | 日本語 | [한국어](README.ko.md)

Codex と Claude Code の両方で使える、エージェント向けターミナルプロセス管理スキルです。

`process-guard` は、coding agent が長時間実行されるコマンドで停止したままになることや、開発サーバー、worker、indexer、bot、daemon、shell、フォアグラウンドの Docker プロセス、watch モードなどの孤立プロセスを残すことを防ぎます。

## 機能

- 実行前にコマンドを有限の一回実行、長時間実行、対話式のいずれかに分類します。
- 有限コマンドを guarded wrapper と明示的な timeout で実行します。
- 長時間実行コマンドを管理対象のバックグラウンドプロセスとして起動します。
- `.agent-run/` 配下に PID、metadata、log を記録します。
- health URL、TCP port、カスタム probe、log pattern で readiness を確認します。
- 親 PID だけでなく、管理対象プロセスを再帰的に停止します。

## インストール

ユーザーレベルにインストールし、Codex と Claude Code の両方で使う場合:

```bash
./scripts/install.sh --target both --scope user
```

リポジトリレベルにインストールし、両方のツールで使う場合:

```bash
./scripts/install.sh --target both --scope project
```

PowerShell:

```powershell
.\scripts\install.ps1 -Target both -Scope user
.\scripts\install.ps1 -Target both -Scope project
```

手動インストール先:

```text
Codex user:       ~/.agents/skills/process-guard/
Codex repo:       .agents/skills/process-guard/
Claude Code user: ~/.claude/skills/process-guard/
Claude Code repo: .claude/skills/process-guard/
```

## クイック使用例

timeout 付きで有限コマンドを実行します:

```bash
"$PROCESS_GUARD_DIR/scripts/guarded-run.sh" --timeout 120 -- npm test
```

一時的な開発サーバーを起動し、応答を確認してから自動的に停止します:

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

## 永続的な指示

より厳密に適用したい場合は、該当する snippet を agent の永続的な指示に貼り付けてください。

```text
references/AGENTS.md.snippet
references/CLAUDE.md.snippet
```

## 実行状態

管理対象プロセスの状態は、デフォルトで `.agent-run/` に書き込まれます。

```text
.agent-run/logs/
.agent-run/pids/
.agent-run/meta/
```

必要に応じて `PROCESS_GUARD_RUN_DIR` で上書きできます。

## ドキュメント

- [インストールガイド](references/install.md)
- [例](references/examples.md)
- [長時間実行パターン](references/long-running-patterns.md)
- [プラットフォームノート](references/platforms.md)
- [トラブルシューティング](references/troubleshooting.md)

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
