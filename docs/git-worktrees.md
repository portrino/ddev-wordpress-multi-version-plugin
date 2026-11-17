# Git worktrees

Several checkouts of the plugin can run side by side, e.g. one per branch,
each as its own DDEV project with its own hostnames.

## One-time setup

Let DDEV take the project name from the directory instead of a fixed `name:`
in `.ddev/config.yaml`. Remove that line and commit it, or set it globally:

```bash
ddev config global --omit-project-name-by-default=true
```

## Per worktree

Create the worktree as a sibling of the primary checkout, with a directory name
that is a valid DNS label:

```bash
git worktree add ../my-plugin-feature feature/x
cd ../my-plugin-feature
ddev worktree-init   # hostnames 71.my-plugin-feature.ddev.site, …
ddev restart
ddev install all
```

`ddev worktree-init` writes `.ddev/config.zz-worktree.local.yaml` with the
hostnames of this checkout. The add-on adds it to `.gitignore`. Run it again
after changing `WP_VERSIONS`.

`.Build/` isn't shared, so every worktree installs its own instances. A bare
`404 page not found` right after the restart comes from the DDEV router;
restart once more.

## Removing a worktree

Run `ddev worktree-remove` inside the worktree. It deletes the DDEV project
and prints the commands to run in the primary checkout:

```bash
git worktree remove --force ../my-plugin-feature
git branch -D feature/x
```
