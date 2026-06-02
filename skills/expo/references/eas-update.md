# EAS Update: runtime versions, channels, rollouts

Deep dive for the OTA-JS half of the pipeline. EAS Update ships **JavaScript and
asset** changes over the air; anything touching native code needs a new `eas build`.

## The exact-match rule (read this first)

An update is delivered to a build only when **BOTH** of these match **exactly**:

1. the **platform** (`ios` / `android`), and
2. the **`runtimeVersion`** of the build and the update.

There is no fuzzy/semver matching. A build with runtime `42` will never receive an
update published under runtime `43`, even if "43 is newer". This single rule
explains the vast majority of "my update isn't showing up" reports.

## Runtime version policies

Set `runtimeVersion` in `app.config`/`app.json`. Pick a *policy* object, not a
literal string, so it tracks the native runtime automatically.

| Policy | Behaviour | Use when |
|---|---|---|
| `{ "policy": "fingerprint" }` | EAS hashes everything affecting the native runtime (deps, config, plugins) and derives the runtime version; auto-bumps on any native change | **default** — safest; impossible to serve JS to an incompatible binary |
| `{ "policy": "appVersion" }` | runtime tied to `version` | you already discipline yourself to bump `version` on every native change |
| `"1.0.0"` (literal) | frozen; you bump by hand | almost never — drifts silently from the binary |

```jsonc
// GOOD default
{ "expo": { "runtimeVersion": { "policy": "fingerprint" } } }
```

`expo-updates` reads this at build time and stamps the binary; the same value is
computed when you `eas update`, and the two are compared by the exact-match rule.

## Channel → branch → update

- **Channel**: stamped onto each build via the `eas.json` profile's `"channel"`.
  It is baked into the binary and cannot be changed without a new build.
- **Branch**: where updates are published. A channel maps to a same-named branch by
  default; you can repoint a channel to a different branch (e.g. promote `staging`'s
  branch to the `production` channel) without rebuilding.
- **Update**: one publish to a branch.

```bash
eas update --branch production --message "fix checkout copy"
eas channel:view production          # see which branch a channel points at
eas channel:edit production --branch release-2025-06   # repoint without rebuilding
eas branch:list
eas update:list --branch production
```

Promotion pattern: build once with the `preview`/`production` channel, publish to
the `staging` branch, validate, then repoint the `production` channel at that same
branch — the binary never changes, only which JS it pulls.

## Rollouts and rollbacks

There are two distinct rollout mechanisms; pick by what you are ramping.

**Per-update rollout** (ramp one new update against the branch's prior update):
publish with `--rollout-percentage <1-100>`, then adjust with `eas update:edit`.

```bash
# Publish to 10% of the channel's devices, then ramp.
eas update --branch production --message "v2 flow" --rollout-percentage 10
eas update:edit --branch production --rollout-percentage 50   # ramp (then 100)
```

**Branch-based rollout** (gradually switch a channel's traffic to a different
branch — e.g. a hotfix branch): managed with `eas channel:rollout`.

```bash
# Start a rollout sending 10% of the production channel to the hotfix branch.
eas channel:rollout production --action=create --percent=10 --branch=hotfix-123
eas channel:rollout production --action=edit --percent=50    # ramp
eas channel:rollout production --action=view                 # inspect state
eas channel:rollout production --action=end                  # commit / finish
```

Roll back by republishing the previous good update as the *newest* one (optionally
itself rolled out gradually), or by repointing the channel:

```bash
# Republish a known-good update group as the newest update; can itself be staged.
eas update:republish --branch production --group <previous-update-group-id> --rollout-percentage 100

# Or point a channel back at a known-good branch.
eas channel:edit production --branch release-last-good
```

`republish` is preferred over deleting: it makes the older bundle the *newest*
update on the branch, so devices move forward (clients only ever roll forward to a
newer update id), not into an undefined state.

## Embedded vs downloaded updates

Every build embeds the JS bundle it was compiled with — that is the fallback shown
on first launch and offline. Downloaded updates are fetched on the *next* launch
after the current one (default check-on-launch), not mid-session, unless you call
the `expo-updates` API to fetch and reload explicitly.

## "Update not applying" — debug flow

Work top to bottom; stop at the first mismatch:

1. **Runtime mismatch?** Compare the build's runtime version with the update's
   (`eas update:list`). Different → the binary can never see it. Rebuild or
   republish under the matching runtime.
2. **Wrong channel/branch?** `eas channel:view <channel>` — is it pointing at the
   branch you published to? Repoint or republish to the right branch.
3. **Native change shipped as JS?** If you bumped a native dependency or changed
   native config, an OTA update cannot deliver it — `eas build` a new binary.
4. **Rollout < 100%?** A gradual rollout only reaches a fraction of devices; ramp it.
5. **Launch timing?** The update installs on the *next* cold start; a device that
   hasn't relaunched still runs the old bundle.
6. **`expo-updates` disabled / dev build?** Updates are off in development mode and
   when `expo-updates` isn't installed/configured.
