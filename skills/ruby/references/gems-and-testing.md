# Gems, Bundler, and testing, in depth

## bundle gem layout

`bundle gem tally` scaffolds a conventional gem:

```text
tally/
├── tally.gemspec
├── Gemfile                 # usually just: gemspec
├── Rakefile
├── lib/
│   ├── tally.rb            # requires lib/tally/version.rb, defines the module
│   └── tally/
│       └── version.rb      # Tally::VERSION = "0.1.0"
├── sig/
│   └── tally.rbs           # optional RBS signatures
└── test/  (or spec/)
    ├── test_helper.rb
    └── tally_test.rb
```

`lib/tally.rb` is the entry point loaded by `require "tally"`. Keep the public API in
the top-level module; put implementation in `lib/tally/`.

## The .gemspec

```ruby
# frozen_string_literal: true

require_relative "lib/tally/version"

Gem::Specification.new do |spec|
  spec.name        = "tally"
  spec.version     = Tally::VERSION
  spec.summary     = "Count word frequencies."
  spec.description = "A tiny, dependency-free word-frequency counter."
  spec.authors     = ["You"]
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/you/tally"

  spec.required_ruby_version = ">= 3.4"
  spec.files     = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.3"          # runtime dep, pessimistic constraint
  spec.metadata["rubygems_mfa_required"] = "true"
end
```

Declare development tools (rake, minitest, rubocop) in the `Gemfile`'s `:development`
group or via `spec.add_development_dependency`, not as runtime deps.

## SemVer and version constraints

Versions are `MAJOR.MINOR.PATCH`. Bump MAJOR on a breaking change, MINOR on a
backward-compatible feature, PATCH on a fix.

| Constraint | Allows | Use for |
|------------|--------|---------|
| `~> 1.3`   | `>= 1.3.0, < 2.0` | Library deps — accept features and fixes, block breaks |
| `~> 1.3.2` | `>= 1.3.2, < 1.4.0` | Pin to a patch line when a minor broke you |
| `>= 1.3`   | any future major | Rarely; you are promising forward compat |
| `= 1.3.2`  | exactly that | Last resort; you own the upgrade churn |

`Gemfile.lock`: commit it for **applications** (reproducible installs everywhere); do
**not** commit it for a published **library** gem — let each consumer resolve against
their own dependency graph.

## Publishing to RubyGems

```bash
gem build tally.gemspec          # produces tally-0.1.0.gem
gem push tally-0.1.0.gem         # uploads to rubygems.org (needs an account + MFA)
```

`bundle exec rake release` automates tag + build + push when the Rakefile uses the
Bundler gem tasks.

## Rakefile with a test task

```ruby
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
```

Run with `bundle exec rake test` (or just `bundle exec rake`).

## Minitest, full file

Minitest ships with Ruby. Both an `assert`-style and a spec-style exist; assert-style
is the low-ceremony default.

```ruby
# test/tally_test.rb
# frozen_string_literal: true

require "minitest/autorun"
require "tally"

class TallyTest < Minitest::Test
  def setup
    @sentence = "the cat the hat the"
  end

  def test_counts_each_word
    assert_equal({ "the" => 3, "cat" => 1, "hat" => 1 }, Tally.count(@sentence))
  end

  def test_empty_string_is_empty_hash
    assert_empty Tally.count("")
  end

  def test_raises_on_nil
    assert_raises(TypeError) { Tally.count(nil) }
  end
end
```

## RSpec, full spec

RSpec is the dominant third-party DSL. Use `let` for lazy fixtures, `subject` for the
object under test, and `context` to group scenarios.

```ruby
# spec/tally_spec.rb
# frozen_string_literal: true

require "tally"

RSpec.describe Tally do
  describe ".count" do
    subject(:counts) { described_class.count(sentence) }

    context "with repeated words" do
      let(:sentence) { "the cat the hat the" }

      it { is_expected.to include("the" => 3) }
      it { is_expected.to eq("the" => 3, "cat" => 1, "hat" => 1) }
    end

    context "with an empty string" do
      let(:sentence) { "" }

      it { is_expected.to be_empty }
    end

    context "with nil" do
      let(:sentence) { nil }

      it "raises" do
        expect { counts }.to raise_error(TypeError)
      end
    end
  end
end
```

Run with `bundle exec rspec`. Add a `.rspec` file with `--require spec_helper` to load
shared config.

## The implementation, idiomatically

The gem these tests describe — note `each_with_object`/`tally`, the magic comment, and
the module namespace, with no metaprogramming:

```ruby
# lib/tally.rb
# frozen_string_literal: true

require_relative "tally/version"

module Tally
  def self.count(text)
    text.split.tally          # Enumerable#tally does the whole job
  end
end
```

## RuboCop vs Standard

```yaml
# .rubocop.yml — full control, every cop tunable
AllCops:
  TargetRubyVersion: 3.4
  NewCops: enable
Metrics/MethodLength:
  Max: 15
Style/StringLiterals:
  EnforcedStyle: double_quotes
```

```ruby
# Gemfile — zero-config alternative; no config file to bikeshed
gem "standard", group: :development
# run: bundle exec standardrb
```

Pick **Standard** when you want to end style arguments; pick **RuboCop** when the team
wants to dial individual cops. Run whichever in CI as a non-negotiable gate.
