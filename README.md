[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/portrino/ddev-wordpress-multi-version-plugin/actions/workflows/tests.yml/badge.svg?branch=master)](https://github.com/portrino/ddev-wordpress-multi-version-plugin/actions/workflows/tests.yml?query=branch%3Amain)

# DDEV WordPress Multi-Version Plugin

Testing a WordPress plugin against several WordPress versions in one DDEV
project. Every version gets its own Composer-based instance in `.Build/<label>`,
its own database and its own hostname; the plugin is required from the project
root through a path repository and activated.

| WordPress | Hostname | Directory | Database |
|---|---|---|---|
| 6.4 | `https://64.<project>.ddev.site` | `.Build/64` | `wp_64` |
| 7.1 | `https://71.<project>.ddev.site` | `.Build/71` | `wp_71` |

Inspired by [ddev-typo3-multi-version-extension](https://github.com/konradmichalik/ddev-typo3-multi-version-extension).

## Requirements

- DDEV >= v1.24.10, webserver type `apache-fpm` or `nginx-fpm`
- The plugin in the project root, with a `composer.json` that has a `name` and
  `"type": "wordpress-plugin"`. The plugin directory in the instances is
  `extra.installer-name` or the package name without vendor, the same name
  `composer/installers` uses.

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
| `ddev install [<version>\|all] [--multisite] [-v]` | (Re)installs instances: deletes the directory and the database, builds a Composer project with `roots/wordpress`, the plugin, the theme and the extra packages from `project.sh`, installs WordPress (multisite: subdirectories), activates the theme and all plugins. `-v` shows all output |
| `ddev <label> <command>` | Runs a command in one instance, e.g. `ddev 71 wp plugin list` |
| `ddev all <command>` | Runs a command in every instance, e.g. `ddev all wp cache flush` |

`<version>` is `7.1` or the label `71`. Login: `/wp-admin/` with `admin` / `Password1!`.

## Instance layout

Each instance follows the layout of our Composer-based WordPress projects:

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

`<version>` installs the newest patch release (`~7.1.0`). The instances run
with `WP_DEBUG` (log in `public/wp-content/debug.log`) and
`AUTOMATIC_UPDATER_DISABLED`, so no instance updates itself away from its
version. `/wp-admin/` and `/wp-source/wp-admin/` both work.

## Configuration

Put overrides in `.ddev/docker-compose.zz-project.yaml`. It belongs to the
project, survives `ddev add-on get` and wins over the add-on's
`docker-compose.wordpress-setup.yaml`:

```yaml
services:
  web:
    environment:
      - WP_VERSIONS=6.4 6.9 7.1
```

- `WP_VERSIONS`: `<major>.<minor>` versions, default `6.4 7.1`. Hostnames and
  `ddev <label>` commands are generated from it, so run `ddev add-on get
  portrino/ddev-wordpress-multi-version-plugin` and `ddev restart` after a change.
- `SYMLINK_EXCLUSIONS`: root entries of the plugin not linked into the
  instances, default `vendor node_modules`.
- `WP_DB_USERNAME`, `WP_DB_PASSWORD`, `WP_DB_HOST`, `WP_SETUP_ADMIN_USERNAME`,
  `WP_SETUP_ADMIN_PASSWORD`, `WP_SETUP_ADMIN_EMAIL`: database and admin login.

### `project.sh`: theme, extra plugins, Composer settings

Copy `.ddev/.setup/project.sh.example` to `.ddev/.setup/project.sh`. It belongs to
the project and survives `ddev add-on get`.

| Variable | Default | Effect |
|---|---|---|
| `THEME_PACKAGES` | `wpackagist-theme/twentytwentyfour` | Theme packages, replace the default |
| `THEME` | `twentytwentyfour` | Theme that gets activated |
| `ADDITIONAL_PACKAGES` | – | Extra packages (e.g. from wpackagist or a private repository), activated together with the plugin |
| `COMPOSER_CONFIG` | – | Extra `composer config` calls, e.g. a private repository |
| `FIXTURE_PACKAGE_DIRS` | `Tests/Acceptance/Fixtures/packages` | Subdirectories with a `composer.json` become available through the path repository |

A child theme lives in the plugin repository, e.g.
`Tests/Acceptance/Fixtures/packages/my-child-theme/` with `style.css`
(`Template: <parent>`) and a `composer.json`:

```json
{
    "name": "test/my-child-theme",
    "type": "wordpress-theme",
    "require": {"wpackagist-theme/twentytwentyfive": "*"}
}
```

```bash
# .ddev/.setup/project.sh
THEME_PACKAGES=('test/my-child-theme:*@dev')
THEME='my-child-theme'
```

### Hooks

For steps that don't fit a variable, add `.ddev/.setup/hooks/<name>.sh`. Hooks are
sourced, see `$version`, `$label`, `$path`, `$url`, `$database`, `$multisite` and
`$slug`, and from `post-composer` on run inside the instance, where a plain `wp`
works. A failing command aborts the install with its output.

| Hook | Runs |
|---|---|
| `pre-install` | Before the instance is deleted and rebuilt |
| `post-composer` | After `composer require`, before WordPress is installed |
| `post-wp-setup` | After WordPress is installed and the theme and plugins are activated |
| `post-install` | Last |

```bash
# .ddev/.setup/hooks/post-wp-setup.sh
wp plugin deactivate classic-editor --quiet
if [ "$multisite" = "1" ]; then
    wp site create --slug=second --quiet
fi
```

### Private Composer repositories

Premium plugins often come from a private Composer repository, e.g.
[Private Packagist](https://packagist.com) or a [SatisPress](https://github.com/cedaro/satispress)
instance. Add the repository with `COMPOSER_CONFIG` and the packages with
`ADDITIONAL_PACKAGES`. Credentials never go into the project. Put a global `auth.json` into DDEV's
homeadditions, it is copied into every web container:

```bash
mkdir -p ~/.ddev/homeadditions/.composer
ln -s ~/.composer/auth.json ~/.ddev/homeadditions/.composer/auth.json
```

## Notes

- The primary URL `https://<project>.ddev.site` has no site of its own (403),
  and DDEV's own `ddev wp` points there too. Use `ddev <label> wp …` or `ddev all wp …`.
- The project root is mounted a second time at `/var/www/plugin`, and
  `packages/<slug>` links there. WordPress maps a symlinked plugin to its real
  directory; with `/var/www/html`, which also contains `.Build`, every other
  plugin's `plugin_basename()` and asset URLs would break. With Mutagen (macOS)
  this second mount is a plain bind mount.
- DDEV custom commands don't keep quoting, so `ddev 71 wp eval '…'` breaks on
  `$`/`;`. Use `ddev exec "cd .Build/71 && wp eval-file file.php"` instead.
- The webserver configs (`apache/wordpress-versions.*`, `nginx_full/wordpress-versions.conf`)
  do WordPress' `.htaccess` rewrites themselves, including subdirectory multisite.
  To customize one, remove its `#ddev-generated` line.

## Remove

```bash
ddev add-on remove wordpress-multi-version-plugin
```

`.Build/` and the databases stay.
