# Configuration

Everything here lives in files that belong to the project and survive
`ddev add-on get`:

| File | For |
|---|---|
| `.ddev/docker-compose.zz-project.yaml` | [Environment variables](#environment-variables): versions, symlink exclusions, credentials |
| `.ddev/.setup/project.sh` | [Theme, extra plugins, Composer settings, fixtures](#projectsh) |
| `.ddev/.setup/hooks/<name>.sh` | [Install hooks](#hooks) |
| `Tests/Acceptance/Fixtures/` | [Fixtures](#fixtures) |

## Environment variables

Put overrides in `.ddev/docker-compose.zz-project.yaml` (a template is in
`.ddev/.setup/docker-compose.zz-project.yaml.example`). It sorts after the
add-on's `docker-compose.wordpress-setup.yaml`, so its values win:

```yaml
services:
  web:
    environment:
      - WP_VERSIONS=6.4 6.9 7.1
```

| Variable | Default | Effect |
|---|---|---|
| `WP_VERSIONS` | `6.4 7.1` | `<major>.<minor>` versions, one instance each |
| `SYMLINK_EXCLUSIONS` | `vendor node_modules` | Root entries of the plugin not linked into the instances |
| `WP_DB_USERNAME`, `WP_DB_PASSWORD`, `WP_DB_HOST` | `root`, `root`, `db` | Database access |
| `WP_SETUP_ADMIN_USERNAME`, `WP_SETUP_ADMIN_PASSWORD`, `WP_SETUP_ADMIN_EMAIL` | `admin`, `Password1!`, `admin@example.com` | Admin login |

Hostnames and the `ddev <label>` commands are generated from `WP_VERSIONS`, so
after a change run `ddev add-on get portrino/ddev-wordpress-multi-version-plugin`
and `ddev restart` (in a [worktree](git-worktrees.md) also `ddev worktree-init`).

## `project.sh`

Copy `.ddev/.setup/project.sh.example` to `.ddev/.setup/project.sh`.

| Variable | Default | Effect |
|---|---|---|
| `THEME_PACKAGES` | `wpackagist-theme/twentytwentyfour` | Theme packages, replace the default |
| `THEME` | `twentytwentyfour` | Theme that gets activated |
| `ADDITIONAL_PACKAGES` | – | Extra packages (e.g. from wpackagist or a private repository), activated together with the plugin |
| `COMPOSER_CONFIG` | – | Extra `composer config` calls, e.g. a private repository |
| `FIXTURES_DIR` | `Tests/Acceptance/Fixtures` | [Fixtures](#fixtures) imported on every install |
| `FIXTURE_PACKAGE_DIRS` | `Tests/Acceptance/Fixtures/packages` | Subdirectories with a `composer.json` become available through the path repository |

```bash
# .ddev/.setup/project.sh
ADDITIONAL_PACKAGES=('wpackagist-plugin/classic-editor:*')
```

### Child theme

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

### Private Composer repositories

Premium plugins often come from a private Composer repository, e.g.
[Private Packagist](https://packagist.com) or a [SatisPress](https://github.com/cedaro/satispress)
instance. Add the repository with `COMPOSER_CONFIG` and the packages with
`ADDITIONAL_PACKAGES`:

```bash
# .ddev/.setup/project.sh
COMPOSER_CONFIG=('repositories.acme composer https://composer.example.com/')
ADDITIONAL_PACKAGES=('acme/premium-plugin:^2.0')
```

Credentials never go into the project. Put a global `auth.json` into DDEV's
homeadditions, it is copied into every web container:

```bash
mkdir -p ~/.ddev/homeadditions/.composer
ln -s ~/.composer/auth.json ~/.ddev/homeadditions/.composer/auth.json
```

## Fixtures

After `post-wp-setup`, every install imports the files in `FIXTURES_DIR` into
the instance (multisite: the main site):

| File | Import |
|---|---|
| `*.sql` | `wp db import`, tables use the prefix `wp_` |
| `*.xml` | WordPress export (WXR) via `wp import --authors=create`; `wordpress-importer` is added only then |
| `*.sh` | Run inside the instance with `WP_VERSION`, `WP_LABEL`, `WP_URL`, `WP_MULTISITE`; a failing script is reported, not fatal |

For demo content, put WordPress' [theme unit test data](https://github.com/WordPress/theme-test-data)
(`themeunittestdata.wordpress.xml`) there.

## Hooks

For steps that don't fit a variable, add `.ddev/.setup/hooks/<name>.sh`. Hooks
are sourced, see `$version`, `$label`, `$path`, `$url`, `$database`,
`$multisite` and `$slug`, and from `post-composer` on run inside the instance,
where a plain `wp` works. A failing command aborts the install with its output.

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

## Webserver configs

`apache/wordpress-versions.*` and `nginx_full/wordpress-versions.conf` route by
the numeric host label and do WordPress' `.htaccess` rewrites themselves,
including subdirectory multisite. To customize one, remove its
`#ddev-generated` line; DDEV then leaves it alone on updates.

The project root is mounted a second time at `/var/www/plugin`, and
`packages/<slug>` links there. WordPress maps a symlinked plugin to its real
directory; with `/var/www/html`, which also contains `.Build`, every other
plugin's `plugin_basename()` and asset URLs would break. With Mutagen (macOS)
this second mount is a plain bind mount.
