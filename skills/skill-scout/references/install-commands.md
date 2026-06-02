# Install commands & scope mechanics

The full menu skill-scout emits once it has a verdict. The SKILL.md body keeps only the three
common forms; the rest lives here so the body stays a decision tool.

## Where Claude Code looks for skills

The available-skills list is built by scanning, in order:

- **User scope** — `~/.claude/skills/<id>/SKILL.md`. Available in *every* project on this machine.
- **Project scope** — `.claude/skills/<id>/SKILL.md`. Version-controlled with the repo; available
  only inside it. A project-scope skill of the same id shadows a user-scope one.
- **Plugin-provided** — skills bundled in an installed plugin/marketplace.
- **Built-ins** — shipped with the harness.

"Present but not here" is therefore a real gap: a skill at user scope is invisible inside a repo
that doesn't pick it up, and a skill committed to one repo's `.claude/skills/` does not follow you
to another.

## Choosing scope (the only decision that matters here)

| Choose **User** (`~/.claude/skills/`) when… | Choose **Project** (`.claude/skills/`) when… |
| --- | --- |
| The skill is general-purpose — you'll want it across repos | The skill encodes this repo's conventions / endpoints |
| It is your personal tooling, not the team's | It should travel with the code for everyone who clones |
| You don't want it in version control | You want it reviewed and versioned in the repo |

Default heuristic: **broad reuse → user; repo-specific → project, committed.**

## Form 1 — plugin marketplace

When the skill is published in a marketplace repo:

```bash
/plugin marketplace add <user>/<repo>     # register the marketplace once
/plugin install <name>@<marketplace>      # install the named skill from it
```

## Form 2 — interactive browser

When you'd rather browse and pick scope by hand:

```bash
/plugin            # opens the plugin UI
                   # → Discover tab → find the skill → Install
                   # → choose User (all projects) or Project (this repo) scope
```

## Form 3 — direct file drop

When you already hold the `SKILL.md` (e.g. copying from another project or a tarball):

```bash
# project scope (committed with the repo)
mkdir -p .claude/skills/<id>
cp -R <source>/<id>/* .claude/skills/<id>/

# user scope (all projects)
mkdir -p ~/.claude/skills/<id>
cp -R <source>/<id>/* ~/.claude/skills/<id>/
```

## Form 4 — curl | tar (remote tarball)

When the skill ships as a downloadable archive rather than a marketplace entry:

```bash
mkdir -p .claude/skills/<id>
curl -fsSL <url>/<id>.tar.gz | tar -xz -C .claude/skills/<id> --strip-components=1
```

## After installing

The new skill is picked up on the next session/scan. Confirm the description is trigger-rich enough
to actually fire — a freshly installed skill with a weak description is still an invisible gap.
If the description is vague, that is an author-skill job, not a re-install.
