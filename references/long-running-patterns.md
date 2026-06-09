# Long-running command classification

Do not classify by language alone. Classify by runtime behavior.

## Long-running by behavior

A command is long-running if it:

- opens a listener
- serves HTTP, WebSocket, RPC, gRPC, Stratum, or database traffic
- watches files
- reloads automatically
- waits for queue jobs
- follows logs
- subscribes to blockchain, exchange, or messaging events
- runs a miner, indexer, bot, market maker, scheduler, or daemon
- stays alive after successful startup

## Usually finite

These are usually finite, but still need timeouts:

```bash
npm test
pnpm build
pytest
cargo test
go test ./...
python scripts/check.py
php artisan migrate --pretend
```

## Usually long-running

```bash
npm run dev
pnpm dev
next dev
vite
python -m http.server 8000
python manage.py runserver
uvicorn app:app --reload
gunicorn app:app
celery -A app worker
rq worker
streamlit run app.py
cargo run
cargo watch -x run
go run ./cmd/server
air
mvn spring-boot:run
gradle bootRun
java -jar app.jar
dotnet run
dotnet watch
php artisan serve
php artisan queue:work
docker compose up
kubectl logs -f
tail -f app.log
```

## Ambiguous commands

These require project inspection:

```bash
cargo run
go run .
python main.py
node index.js
java -jar app.jar
```

If the target is a CLI that exits, use `guarded-run`. If it starts a server, worker, bot, miner, indexer, daemon, scheduler, or listener, use managed background execution.
