# Metaprogramming, in depth

Ruby's dynamism is a power tool, and the default answer is *don't*: a plain method,
`Struct`, `Data`, or Hash is more discoverable than a clever interception. Reach here
only when the boring version produces real, repeated boilerplate, and always pick the
most reversible, most introspectable tool that does the job.

Order of preference: **plain method -> `define_method` -> `method_missing` (last
resort, always paired)**.

## define_method — dynamic names, real methods

`define_method` defines an actual method visible to `respond_to?`, `method`, docs, and
tooling. Use it to collapse repetitive accessor/delegation boilerplate.

```ruby
# frozen_string_literal: true

class Settings
  def initialize(**data) = @data = data

  %i[host port timeout].each do |key|
    define_method(key)       { @data.fetch(key) }
    define_method("#{key}?") { !@data[key].nil? }
  end
end

s = Settings.new(host: "db", port: 5432, timeout: nil)
s.respond_to?(:port)   # => true   (a real method)
s.timeout?             # => false
```

The block captures its surrounding scope (a closure), so `key` is available inside
each generated method. That is the whole reason to prefer it over `eval`-built strings.

## method_missing — and why it must be paired

`method_missing` intercepts calls to methods that do not exist. It is slower (every
miss walks the ancestry chain first), invisible to introspection, and easy to leave
buggy. If you use it, you **must** also define `respond_to_missing?`, or `respond_to?`,
`method(...)`, and any duck-typing check will lie about your object.

```ruby
# frozen_string_literal: true

# A read-only view over a Hash with dotted access. method_missing is justified here
# because the key set is open and data-driven — you cannot define_method them ahead.
class OpenRecord
  def initialize(attrs) = @attrs = attrs

  def method_missing(name, *args)
    return @attrs[name] if @attrs.key?(name) && args.empty?

    super   # preserve normal NoMethodError for genuinely unknown calls
  end

  def respond_to_missing?(name, include_private = false)
    @attrs.key?(name) || super
  end
end

r = OpenRecord.new(name: "Ada", lang: "Ruby")
r.name                 # => "Ada"
r.respond_to?(:lang)   # => true   (because respond_to_missing? is defined)
r.nope                 # => NoMethodError, via super
```

Always call `super` in the fall-through branch so unhandled names raise the normal
`NoMethodError` instead of returning `nil` silently.

## instance_eval / class_eval

- `instance_eval` runs a block with `self` rebound to the receiver — the basis of
  configuration DSLs where the block "is" the object being configured.
- `class_eval` (a.k.a. `module_eval`) runs a block in a class's definition context, so
  `def` inside it defines instance methods. Prefer the block form over the string form;
  the string form loses lexical scope and gives bad backtraces.

## A small, justified DSL

A DSL earns its place when the *call site* reads dramatically better than passing a
Hash and the surface is stable. Build it on `instance_eval`, collecting plain data:

```ruby
# frozen_string_literal: true

class RouteSet
  def self.draw(&block)
    set = new
    set.instance_eval(&block)
    set.routes
  end

  attr_reader :routes

  def initialize = @routes = []

  def get(path, to:)  = @routes << { verb: :get,  path:, to: }
  def post(path, to:) = @routes << { verb: :post, path:, to: }
end

routes = RouteSet.draw do
  get  "/health", to: "system#health"
  post "/orders", to: "orders#create"
end
# => [{verb: :get, path: "/health", to: "system#health"}, ...]
```

Note it ends in a plain array of hashes — the DSL is a thin front, not a maze of
dynamic dispatch. If the config is one level deep, skip the DSL and accept a Hash.

## Refinements vs monkey-patching

Monkey-patching reopens a core class globally, so the change leaks into every file and
every gem in the process — the classic source of "it worked until I added that gem"
bugs. A **refinement** scopes the patch to files that opt in with `using`.

```ruby
# frozen_string_literal: true

module StringTitleize
  refine String do
    def titleize = split.map(&:capitalize).join(" ")
  end
end

# Only active below this line, only in this file.
using StringTitleize
"hello world".titleize   # => "Hello World"
```

Rules: refinements are lexically scoped (active from the `using` line to end of file or
module), do not affect other files, and are reversible by simply not requiring them.
Prefer them to monkey-patching whenever you must add behavior to a class you do not own.

## prepend for wrapping

To wrap an existing method (logging, memoization, instrumentation) without `alias`
gymnastics, put the wrapper in a module and `prepend` it so it sits *before* the class
in the lookup chain and can call `super`:

```ruby
# frozen_string_literal: true

module Timed
  def call(*)
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    super
  ensure
    warn("#{self.class}#call took #{Process.clock_gettime(Process::CLOCK_MONOTONIC) - t}s")
  end
end

class Job
  prepend Timed
  def call = do_work
end
```

`super` reaches the original `Job#call` because `Timed` was prepended ahead of it.
This is cleaner and more reversible than aliasing the old method out from under callers.
