# Rails testing

Minitest + fixtures is the framework default and what fresh apps ship with. RSpec-rails
is the popular alternative. Pick one per app; don't mix.

## Minitest layout (default)

```text
test/
  models/         ActiveSupport::TestCase
  integration/    ActionDispatch::IntegrationTest
  controllers/    ActionDispatch::IntegrationTest
  system/         ApplicationSystemTestCase
  jobs/           ActiveJob::TestCase
  fixtures/       *.yml — loaded once per suite
```

Run: `bin/rails test` (unit/integration), `bin/rails test:system` (browser). Parallel
execution is on by default via `parallelize(workers: :number_of_processors)` in
`test_helper.rb`.

## RSpec-rails setup

```ruby
# Gemfile (test group)
gem "rspec-rails", "~> 8.0"
gem "capybara"
```

```bash
bundle exec rails generate rspec:install   # creates spec/ + spec_helper
```

Specs live under `spec/{models,requests,system,jobs}`. Prefer **request specs** over
controller specs (the Rails team's guidance) — they hit the full middleware stack.

## Fixtures vs factories

- **Fixtures** (default): YAML rows loaded once into the test DB. Fast, but every test
  shares the same data, so they drift toward a tangled global fixture set.
- **Factories** (FactoryBot): build objects per test. More expressive for per-test
  variation, slower if you `create` when `build`/`build_stubbed` would do.

Default to fixtures; introduce FactoryBot when fixture sprawl makes intent unclear.

```yaml
# test/fixtures/posts.yml
one:
  title: First post
  author: alice          # references users.yml by label, resolves the FK
  published_at: <%= 2.days.ago %>
```

Gotcha: fixture labels become stable IDs via a hash — reference associations by label,
never by hard-coded integer ID.

## System-test driver config

Default driver is Selenium + headless Chrome. It's the flakiest with Turbo. Swap to
**Cuprite** (CDP, no Selenium) or **Playwright** to cut timing flake and speed up CI.

```ruby
# test/application_system_test_case.rb (Cuprite example)
require "capybara/cuprite"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [1400, 1400], options: { headless: true }
end
```

Hardening rules:
- Use auto-waiting matchers (`assert_selector`, `assert_text`, `assert_no_selector`,
  `has_no_text?`) — they retry up to Capybara's default wait. Never `sleep N`.
- Assert the *absence* of the old state with `assert_no_*` (also auto-waits) rather than
  asserting presence too early.
- Keep one logical interaction per assertion block so a failure points at the step.

## Testing jobs

```ruby
class CommentNotificationJobTest < ActiveJob::TestCase
  test "enqueues on comment create" do
    assert_enqueued_with(job: CommentNotificationJob) do
      posts(:one).comments.create!(body: "hi")
    end
  end

  test "performs idempotently when comment is gone" do
    assert_nothing_raised { CommentNotificationJob.perform_now(-1) }
  end
end
```

Use `perform_enqueued_jobs` / `assert_enqueued_jobs` to control whether jobs run inline
or just enqueue.

## Testing broadcasts

```ruby
assert_broadcasts [post, :comments], 1 do
  post.comments.create!(body: "live")
end
```

## What to test

Behavior through the public surface: a request returns the right status/redirect/body;
a model method changes state correctly; a job enqueues and is idempotent. Do **not**
test private methods — they're implementation, and locking tests to them turns every
refactor into a test rewrite.
