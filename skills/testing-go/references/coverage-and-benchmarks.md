# Coverage & benchmarks

Coverage profiles (including cross-package and integration binaries) and the `benchstat` benchmarking workflow. Target Go 1.25.

## Coverage profiles

```bash
go test -cover ./...                                   # per-package % to stdout
go test -coverprofile=cover.out ./...                  # write a profile file
go tool cover -func=cover.out                          # per-function % in the terminal
go tool cover -html=cover.out                          # annotated source in the browser
go tool cover -html=cover.out -o cover.html            # write the HTML report to a file
```

The profile is the truth, the percentage is the headline. Open the HTML report and look at which **branches** are red, not at the number. An error path that never executes in any test is worth more attention than three more covered getters.

## Cross-package coverage

By default `go test` only counts coverage of the package under test. When tests live in package `foo_test` or exercise code across the module, that undercounts. Use `-coverpkg`:

```bash
go test -coverpkg=./... -coverprofile=cover.out ./...
go test -coverpkg=./internal/... -coverprofile=cover.out ./internal/api
```

`-coverpkg` names the packages whose coverage to **measure**; the final args name the tests to **run**. They are different lists, which is the whole point — run the API tests, measure the internal packages they reach.

## Integration-binary coverage (Go 1.20+)

To measure coverage of a compiled binary driven by black-box tests (shell scripts, end-to-end harnesses), build with `-cover` and point `GOCOVERDIR` at an output directory:

```bash
go build -cover -o ./bin/app .
mkdir -p covdata
GOCOVERDIR=$(pwd)/covdata ./bin/app --do-something
go tool covdata percent -i=covdata
go tool covdata textfmt -i=covdata -o=cover.out   # convert to a profile for -html
```

This captures coverage from the running process, not from `go test`, so it folds real integration runs into your coverage picture.

## Benchmarks: the loop

Use `for b.Loop()` (Go 1.24+). It excludes setup before the loop and teardown after from the timer automatically, runs the body the correct number of times, and prevents the compiler from dead-code-eliminating the calls inside it.

```go
func BenchmarkEncode(b *testing.B) {
	in := makeFixture()  // excluded from timing
	b.ReportAllocs()
	for b.Loop() {
		_ = Encode(in)
	}
}
```

Always call `b.ReportAllocs()` — allocations regress before wall-clock and are usually the cheapest thing to fix. In pre-1.24 modules you instead write `for i := 0; i < b.N; i++`, call `b.ResetTimer()` after setup, and assign results to a package-level sink (or `runtime.KeepAlive`) to defeat the optimizer. None of that is needed with `b.Loop`.

## benchstat workflow

Never compare two raw benchmark prints — run-to-run noise usually exceeds the change you are measuring. Run each variant multiple times and let `benchstat` report the delta with a confidence interval.

```bash
go install golang.org/x/perf/cmd/benchstat@latest

# on the baseline:
go test -run=^$ -bench=BenchmarkEncode -count=10 ./... > old.txt
# after your change:
go test -run=^$ -bench=BenchmarkEncode -count=10 ./... > new.txt

benchstat old.txt new.txt
```

`-run=^$` disables ordinary tests so only benchmarks run. `-count=10` gives benchstat enough samples to judge significance; treat a result marked `~` (no statistically significant change) as no change, regardless of the sign.

## Profiling hooks

Capture CPU and memory profiles from a benchmark and inspect them with pprof:

```bash
go test -run=^$ -bench=BenchmarkEncode -cpuprofile=cpu.out -memprofile=mem.out ./pkg
go tool pprof -http=:0 cpu.out      # interactive flame graph in the browser
go tool pprof -top mem.out          # top allocation sites in the terminal
```

Profile first, optimize second. A benchmark tells you *that* it is slow; the profile tells you *where*.
