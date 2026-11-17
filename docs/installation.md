# Installing instances

```bash
ddev install [<version>|all] [--multisite] [-v|--verbose]
```

| Argument | Effect |
|---|---|
| `all` (default) | Every version in `WP_VERSIONS` |
| `<version>` | One version, `7.1` or the label `71` |
| `--multisite` | Multisite with subdirectories instead of a single site |
| `-v`, `--verbose` | Show all output instead of the progress lines |

Each run rebuilds the instance from scratch, so it's also the way to reset one.
Per version it:

1. runs the `pre-install` hook,
2. deletes `.Build/<label>` and drops and recreates the database `db_<label>` (with access for DDEV's `db` user, like `ddev import-db`),
3. links the plugin into `packages/<slug>` (without `SYMLINK_EXCLUSIONS`) and
   the local packages from `FIXTURE_PACKAGE_DIRS`,
4. creates a Composer project and requires `roots/wordpress:~<version>.0`, the
   plugin, `THEME_PACKAGES` and `ADDITIONAL_PACKAGES`, then runs the `post-composer` hook,
5. writes `public/wp-config.php`, installs WordPress, activates the theme
   and all plugins (multisite: network-wide), then runs the `post-wp-setup` hook,
6. imports the [fixtures](configuration.md#fixtures) and runs the `post-install` hook.

A failing step aborts the install with its output.

## Instance layout

Each instance follows the layout of a Composer-based WordPress project:

```
.Build/71/
├── composer.json        roots/wordpress ~7.1.0, wpackagist, path repository packages/*
├── packages/<slug>/     symlinks to the project root, without SYMLINK_EXCLUSIONS
├── vendor/              dependencies of the plugin, resolved by the instance
├── wp-cli.yml           path: public/wp-source
└── public/              docroot
    ├── index.php
    ├── wp-config.php    loads vendor/autoload.php, credentials via getenv()
    ├── wp-source/       WordPress core
    └── wp-content/      plugins/<slug> -> packages/<slug>, themes, uploads
```

The plugin's own `vendor/` isn't linked, the instance resolves its
dependencies. A dependency missing from the plugin's `composer.json` therefore
shows up as an error.

`<version>` installs the newest patch release (`~7.1.0`). The instances run
with `WP_DEBUG` (log in `public/wp-content/debug.log`, no display) and
`AUTOMATIC_UPDATER_DISABLED`, so no instance updates itself away from its
version. `ADMIN_COOKIE_PATH` is `/`, so `/wp-admin/` and `/wp-source/wp-admin/`
both work.

Login: `/wp-admin/` with `admin` / `Password1!` (see
[Configuration](configuration.md#environment-variables)).
