# Portability: bash vs POSIX sh, and the macOS bash 3.2 reality

Read this when a script must run somewhere you don't control: an unknown CI
image, a colleague's Mac, an Alpine container, a busybox device. The question
is always the same — **what is the lowest shell this will ever hit, and what
does that shell forbid?**

## Feature matrix

| Feature | bash 4+ | bash 3.2 (macOS `/bin/bash`) | POSIX `sh` (dash/busybox) |
|---|---|---|---|
| `set -o pipefail` | yes | yes | **no** (bashism) |
| Indexed arrays `arr=(…)` / `"${arr[@]}"` | yes | yes | **no** |
| Associative arrays `declare -A` | yes | **no** (3.2 lacks them) | **no** |
| `[[ … ]]`, `=~`, `&&` inside test | yes | yes | **no** (use `[ … ]`) |
| `local` in functions | yes | yes | **no** (not POSIX; dash/ksh have it as an extension) |
| `${var,,}` / `${var^^}` case fold | yes | **no** | **no** |
| `mapfile` / `readarray` | yes | **no** | **no** |
| Process substitution `<(…)` | yes | yes | **no** |
| `${ cmd; }` / `${\| cmd; }`, `GLOBSORT`, `read -E` | bash **5.3+** only | **no** | **no** |
| `[ a == b ]` | tolerated | tolerated | **no** (use `=`) |
| `echo -e` / `echo -n` | unreliable across shells — use `printf` everywhere |

Rule of thumb: if the floor is "any Unix," target POSIX `sh` and give up arrays,
`[[ ]]`, `pipefail`, and `local`. If you control the box and bash is present,
target bash but assume **3.2** unless you've verified otherwise — that rules out
associative arrays, `${var,,}`, and `mapfile`.

## macOS bash 3.2 workarounds

Apple froze `/bin/bash` at **3.2.57** (pre-GPLv3); zsh is the default login
shell since Catalina, but scripts still hit `/bin/bash`. Newer bash from
Homebrew lives at `/opt/homebrew/bin/bash` and is NOT what a `#!/bin/bash`
shebang gets. Portable substitutes:

```bash
# No associative array (declare -A). Use a function + case, or parallel arrays.
lookup() {
  case "$1" in
    dev)  echo "https://dev.example.com" ;;
    prod) echo "https://example.com" ;;
    *)    return 1 ;;
  esac
}

# No ${var,,} lowercasing. Use tr.
lower=$(printf '%s' "$var" | tr '[:upper:]' '[:lower:]')

# No mapfile. Read lines into an array with a loop (or use find -print0).
lines=()
while IFS= read -r line; do
  lines+=("$line")
done < file.txt
```

## dash / busybox gotchas

These bite POSIX-`sh` scripts that were only ever tested under bash:

- `echo -e '\n'` prints the literal `-e` under dash. Use `printf '\n'`.
- `==` inside `[ ]` is a bash extension; dash errors. Use `=`.
- `source file` is a bashism; POSIX is `. file` (dot space).
- `function name {` is a bashism; POSIX is `name() {`.
- `local` works in dash and busybox ash as an extension, but is not in the
  POSIX spec — don't rely on it if "any POSIX sh" is the contract.
- `${arr[@]}` / `(…)` arrays: dash has none. busybox ash has none.

## bash 5.3 features — guard or avoid

Bash **5.3** (released 2025-07) added in-shell command substitution `${ cmd; }`
and `${| cmd; }` (no fork; result in `REPLY`), `GLOBSORT`, `compgen` into a
variable, `read -E`, and C23 conformance. None of these run on bash 3.2 or
POSIX `sh`. If you must use one, gate it on the version and provide a fallback:

```bash
if [ "${BASH_VERSINFO[0]:-0}" -ge 5 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 3 ]; then
  : "use the 5.3 feature"
else
  : "portable fallback"
fi
```

Otherwise, simply don't use them in anything that ships.

## How to test against more than your own shell

```bash
shellcheck script.sh             # default: bash dialect
shellcheck -s sh script.sh       # static check against POSIX sh
dash ./script.sh                 # actually run under dash (apt install dash)
bash --posix ./script.sh         # bash with POSIX-mode restrictions on
docker run --rm -v "$PWD":/s -w /s alpine sh script.sh   # busybox ash
```

Running under `dash` is the cheapest way to surface accidental bashisms that
ShellCheck's `-s sh` mode misses. A script that passes `shellcheck -s sh` AND
runs clean under `dash` is genuinely portable.
