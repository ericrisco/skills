# Queues & scheduling (deep dive)

Offloaded depth from SKILL.md §Queues & scheduling. The body covers `ShouldQueue`, `$tries`,
`backoff()`, batches with `allowFailures()`, and the database-vs-Redis driver decision. This
file covers the operational layer: Horizon, the failure pipeline, and worker deployment.

## Driver selection (expanded)

| Driver | Infra | Choose when |
|---|---|---|
| `sync` | none (runs inline) | local debugging only; **the default in tests** — jobs run inline |
| `database` | a `jobs` + `job_batches` + `failed_jobs` table | low/medium volume, no Redis, simplest ops |
| `redis` | Redis | high throughput, low latency; pair with Horizon |
| `sqs` / others | cloud | you already run on that provider's queue |

Create the tables for the database driver:

```bash
php artisan make:queue-table
php artisan make:queue-batches-table
php artisan migrate
```

## Horizon (Redis only)

Horizon is the first-party dashboard + supervisor for Redis queues — throughput, runtime,
retries, failed jobs, and tag-based metrics, configured in code (not a separate UI to wire).

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan horizon            # runs the supervised workers (instead of queue:work)
```

```php
// config/horizon.php — environment-specific worker pools.
'environments' => [
    'production' => [
        'supervisor-1' => [
            'connection' => 'redis',
            'queue'      => ['high', 'default'],
            'balance'    => 'auto',     // scale processes to load
            'maxProcesses' => 10,
            'tries'      => 3,
            'timeout'    => 120,
        ],
    ],
],
```

In production run `php artisan horizon` under a process supervisor (below). Deploys call
`php artisan horizon:terminate` so workers gracefully finish the current job and restart on
the new code.

## Retry / backoff / timeout matrix

| Knob | Where | Meaning |
|---|---|---|
| `$tries` | job property | max attempts before the job is marked failed |
| `$maxExceptions` | job property | fail after N exceptions even if `$tries` not hit |
| `backoff()` | job method (array) | seconds to wait between attempts (`[10, 60, 300]`) |
| `$timeout` | job property | seconds the worker allows before killing the job |
| `retryUntil()` | job method | a `DateTime` after which it stops retrying (overrides `$tries`) |
| `$backoff` on worker | `queue:work --backoff=` | default wait when a job has no own backoff |

Set `$timeout` **less** than the queue connection's `retry_after` (config/queue.php) — if a
job runs longer than `retry_after`, the queue releases it to a second worker and you get
duplicate processing.

## The failure pipeline

A job that exhausts `$tries` lands in `failed_jobs`. Inspect and replay:

```bash
php artisan queue:failed              # list failed jobs with their UUIDs
php artisan queue:retry <uuid>        # requeue one
php artisan queue:retry all           # requeue everything
php artisan queue:forget <uuid>       # drop one
php artisan queue:flush               # clear the failed table
```

Add a `failed()` method to the job for compensating actions (notify, refund, mark record):

```php
public function failed(\Throwable $e): void {
    $this->order->update(['status' => 'failed']);
    Notification::route('slack', config('alerts.ops'))->notify(new JobFailed($e));
}
```

For batches, `catch()` fires on the first failed job and `finally()` always runs:

```php
Bus::batch($jobs)
    ->allowFailures()
    ->catch(fn (Batch $b, \Throwable $e) => Log::error('batch member failed', ['e' => $e]))
    ->finally(fn (Batch $b) => Log::info("batch {$b->id} done, failures: {$b->failedJobs}"))
    ->dispatch();
```

## Worker deployment

Run workers as a long-lived supervised process — **never** `queue:work` in a bare shell in
prod (it dies with the SSH session and won't restart).

```ini
; /etc/supervisor/conf.d/laravel-worker.conf
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/app/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
numprocs=4
stopwaitsecs=3600   ; let in-flight jobs finish on stop (must exceed longest job)
```

Useful `queue:work` flags:

| Flag | Effect |
|---|---|
| `--max-time=3600` | exit after an hour so a fresh worker reclaims leaked memory |
| `--max-jobs=1000` | exit after N jobs (same memory hygiene) |
| `--tries=3` | default attempts (job's own `$tries` wins) |
| `--queue=high,default` | priority order — drain `high` first |
| `--once` | process a single job then exit (handy in tests/scripts) |

## Graceful restarts on deploy

```bash
php artisan queue:restart       # signals workers to finish the current job then exit
# (supervisor / horizon:terminate then restarts them on the new code)
```

Workers hold the **old** code in memory until restarted — forget `queue:restart` in your
deploy script and you ship a bug fix that never reaches the queue.

## Scheduling

The scheduler lives in `routes/console.php` (L11/12 — no `app/Console/Kernel.php`). One
system cron entry drives it:

```cron
* * * * * cd /var/www/app && php artisan schedule:run >> /dev/null 2>&1
```

```php
// routes/console.php
Schedule::command('orders:reconcile')->dailyAt('02:00')->onOneServer()->withoutOverlapping();
Schedule::job(new PruneStaleCarts)->hourly();
```

`->onOneServer()` (needs a shared cache lock) stops a multi-server fleet running the same
task N times; `->withoutOverlapping()` skips a run if the previous one is still going.
