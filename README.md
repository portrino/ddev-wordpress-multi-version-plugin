[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/portrino/ddev-wordpress-multi-version-plugin/actions/workflows/tests.yml/badge.svg?branch=master)](https://github.com/portrino/ddev-wordpress-multi-version-plugin/actions/workflows/tests.yml?query=branch%3Amain)

# DDEV WordPress Multi-Version Plugin

Testing a WordPress plugin against several WordPress versions in one DDEV
project. Every version gets its own instance in `.Build/<label>`, its own
database and its own hostname; the plugin checkout is symlinked into each
instance and activated.

| WordPress | Hostname | Directory | Database |
|---|---|---|---|
| 6.4 | `https://64.<project>.ddev.site` | `.Build/64` | `wp_64` |
| 7.1 | `https://71.<project>.ddev.site` | `.Build/71` | `wp_71` |

Inspired by [ddev-typo3-multi-version-extension](https://github.com/konradmichalik/ddev-typo3-multi-version-extension).

## Requirements

- DDEV >= v1.24.10, webserver type `apache-fpm` or `nginx-fpm`
- The plugin in the project root, with its main file (the one with the
  `Plugin Name:` header) there too
- A `composer.json` in the project root with a `name` and
  `"type": "wordpress-plugin"`

## Installation

```bash
ddev config --webserver-type=apache-fpm   # or nginx-fpm
ddev add-on get portrino/ddev-wordpress-multi-version-plugin
ddev restart
ddev install all
```

The add-on sets the project type to `wordpress` (for DDEV's WP-CLI) with
`disable_settings_management: true` and the docroot `.Build`, and adds
`.Build/` to `.gitignore`. Commit `.ddev/`.

## Commands

| Command | Description |
|---|---|
| `ddev install [<version>\|all] [--multisite]` | (Re)installs instances: deletes the directory and the database, downloads WordPress, installs it (multisite: subdirectories), symlinks and activates the plugin |
| `ddev <label> <command>` | Runs a command in one instance, e.g. `ddev 71 wp plugin list` |
| `ddev all <command>` | Runs a command in every instance, e.g. `ddev all wp cache flush` |

`<version>` is `7.1` or the label `71`. Login: `/wp-admin/` with `admin` / `Password1!`.

The instances run with `WP_DEBUG` (log in `wp-content/debug.log`) and
`AUTOMATIC_UPDATER_DISABLED`, so no instance updates itself away from its
version.

## Configuration

Put overrides in `.ddev/docker-compose.zz-project.yaml`. It belongs to the
project, survives `ddev add-on get` and wins over the add-on's
`docker-compose.wordpress-setup.yaml`:

```yaml
services:
  web:
    environment:
      - WP_VERSIONS=6.4 6.9 7.1
      - WP_PLUGIN_SLUG=my-plugin
```

- `WP_VERSIONS`: `<major>.<minor>` versions, default `6.4 7.1`. Hostnames and
  `ddev <label>` commands are generated from it, so run `ddev add-on get
  portrino/ddev-wordpress-multi-version-plugin` and `ddev restart` after a change.
- `WP_PLUGIN_SLUG`: directory name of the plugin in `wp-content/plugins`.
  Default: the name of the main file without `.php`.

### Post-install hook

If `.ddev/wordpress-post-install.sh` exists, `ddev install` runs it after each
instance with `WP_VERSION`, `WP_PATH`, `WP_URL` and `WP_MULTISITE` (`0`/`1`)
set, for extra plugins, themes, sites or settings:

```bash
#!/usr/bin/env bash
set -euo pipefail
wp=(wp --path="$WP_PATH" --url="$WP_URL")
"${wp[@]}" plugin install classic-editor --activate --quiet
if [ "$WP_MULTISITE" = "1" ]; then
    "${wp[@]}" site create --slug=second --quiet
fi
```

## Notes

- The primary URL `https://<project>.ddev.site` has no site of its own (403),
  and DDEV's own `ddev wp` points there too. Use `ddev <label> wp …` or `ddev all wp …`.
- The webserver configs (`apache/wordpress-versions.*`, `nginx_full/wordpress-versions.conf`)
  do WordPress' `.htaccess` rewrites themselves, including subdirectory multisite.
  To customize one, remove its `#ddev-generated` line.

## Remove

```bash
ddev add-on remove wordpress-multi-version-plugin
```

`.Build/` and the databases stay.
