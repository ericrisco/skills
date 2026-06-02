# Recon playbook — per-ecosystem patterns & escalation

Offloaded depth for the recon pass in `../SKILL.md`. Pull the rows you need; do not run them all.

## Entry points & hidden side effects by ecosystem

### Node / Express / Next.js
- **Entry**: `package.json` `scripts.start`/`dev` → the bootstrap file (`server.js`, `src/index.ts`). Next.js: routes are files under `app/` (route handlers `route.ts`) or `pages/api/`.
- **Routes**: `rg -n "app\.(get|post|put|delete|use)\(|router\.(get|post|use)\(" src`
- **Side effects**: `setInterval`, `node-cron`, BullMQ (`new Queue`/`Worker`), `EventEmitter.on(`, Next.js `middleware.ts`, `instrumentation.ts`, and `next.config` rewrites/redirects.

### Python / Django / FastAPI
- **Entry (Django)**: `manage.py` → `settings.ROOT_URLCONF` → `urls.py` trees. **FastAPI**: the `FastAPI()` instance + `APIRouter` includes; `uvicorn` target in the run command.
- **Routes**: `rg -n "@app\.(get|post|put|delete)|APIRouter|path\(|re_path\(|router\.register" .`
- **Side effects**: Celery (`@shared_task`, `celery.beat` schedule), Django signals (`@receiver`, `post_save`), management commands (`management/commands/`), `apps.py` `ready()`, middleware list in settings.

### Ruby / Rails
- **Entry**: `config/routes.rb`, `config/application.rb`, initializers in `config/initializers/`.
- **Side effects**: Sidekiq/ActiveJob workers (`app/jobs`, `*_worker.rb`), `whenever` cron schedule, ActiveRecord callbacks (`after_save`, `before_create`), `config/schedule.rb`.

### Go
- **Entry**: `func main()` (find with `rg -n "func main\(\)"`), the router setup (`chi`, `gin`, `mux`, stdlib `http.HandleFunc`).
- **Side effects**: goroutines launched at boot (`go func()`), `time.Ticker`/`cron`, `init()` functions (run before main, easy to miss).

### JVM / Spring Boot
- **Entry**: the `@SpringBootApplication` main class; `application.yml`/`.properties` for active profiles.
- **Routes**: `rg -n "@RestController|@RequestMapping|@GetMapping|@PostMapping" src`
- **Side effects**: `@Scheduled`, `@EventListener`, `@PostConstruct`, `@KafkaListener`/`@RabbitListener`, `@Async`.

### PHP / Laravel
- **Entry**: `routes/web.php`, `routes/api.php`, `public/index.php`.
- **Side effects**: `app/Console/Kernel.php` schedule, jobs in `app/Jobs`, model events/observers (`app/Observers`), event listeners in `EventServiceProvider`.

## Churn × complexity (the richer hotspot signal)

Git churn alone ranks files by change frequency. Multiply by complexity to find the true danger zone — files that change constantly *and* are hard to read.

```bash
# 1. Churn (revisions per file) over a year, via code-maat
git log --pretty=format:'[%h] %an %ad %s' --date=short --numstat --since=12.month > /tmp/log.txt
java -jar code-maat.jar -l /tmp/log.txt -c git2 -a revisions > /tmp/churn.csv

# 2. Complexity per file (reuse scc, or indentation as a cheap proxy)
scc --by-file --format csv . > /tmp/complexity.csv
```

Join the two CSVs on filename; the **top-right quadrant** (high revisions, high complexity) is where bugs concentrate and where tests are missing. Start refactoring/test-writing there, not in the file that merely looks ugly. (adamtornhill/code-maat; understandlegacycode.com Hotspots Analysis; accessed 2026-06-02.)

## When to bring in a tree-sitter dependency graph

Grep + churn answers most first-pass questions. Reach for a structural graph only when the codebase is large enough that "who depends on this" is no longer obvious by eye.

- **codegraph** (tree-sitter + PageRank, no embeddings/GPU): one-shot ranking of files by structural importance, biased toward query keywords. Prefer this one-shot rank for onboarding — it is fast and stateless. (github.com/tarunms7/codegraph)
- **FileScopeMCP**: scores each file 0–10 by how many things depend on it — a quick "what is load-bearing" lens. (github.com/admica/FileScopeMCP)
- **Heavier MCP-native graphs** (codegraph-ai/CodeGraph: ~42 MCP tools across 38 languages; tree-sitter-analyzer): full function/class/import + call/inheritance graphs. Powerful, but standing up a persistent MCP graph server during *first-pass* onboarding is usually overkill — defer until the map exists and you have a concrete deep-dive question. (accessed 2026-06-02.)

**Rule of thumb**: if the repo is under a few hundred files, a tree-sitter graph costs more setup than it saves. Use it for monorepos and for finding the load-bearing packages, not for a service you can grep through in ten minutes.
