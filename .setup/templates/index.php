<?php
// #ddev-generated
// Intro page on https://<project>.ddev.site, copied to .Build/ on every `ddev start`.
// Remove the line above to take this file over, DDEV then won't overwrite it.
declare(strict_types=1);

$h = static fn (string $value): string => htmlspecialchars($value, ENT_QUOTES);
$siteHostname = getenv('DDEV_SITENAME') . '.' . getenv('DDEV_TLD');
$adminUser = (string) getenv('WP_SETUP_ADMIN_USERNAME');
$adminPassword = (string) getenv('WP_SETUP_ADMIN_PASSWORD');
$versions = preg_split('/\s+/', trim((string) getenv('WP_VERSIONS'))) ?: [];

$composer = json_decode((string) @file_get_contents(dirname(__DIR__) . '/composer.json'), true) ?: [];
$name = $composer['name'] ?? getenv('DDEV_SITENAME');
$description = $composer['description'] ?? '';

// Written by the post-start hook, shows which checkout this is (git worktrees)
$gitInfo = is_file(__DIR__ . '/.git-info') ? (parse_ini_file(__DIR__ . '/.git-info') ?: []) : [];

function installedVersion(string $path): ?string
{
    $file = $path . '/public/wp-source/wp-includes/version.php';
    if (is_file($file) && preg_match("/\\\$wp_version = '([^']+)'/", (string) file_get_contents($file), $matches)) {
        return $matches[1];
    }
    return null;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= $h($name) ?></title>
    <style>
        :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
        body { max-width: 52rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
        article { border: 1px solid #8884; border-radius: .5rem; padding: .75rem 1rem; margin: .75rem 0; display: flex; gap: 1.5rem; flex-wrap: wrap; align-items: baseline; }
        kbd { font-size: 1.25rem; font-weight: bold; }
        small { opacity: .7; }
        code { background: #8882; padding: 0 .25rem; border-radius: .25rem; }
    </style>
</head>
<body>
<header>
    <h1><?= $h($name) ?></h1>
    <?php if ($description !== ''): ?><p><?= $h($description) ?></p><?php endif; ?>
    <p>
        <code><?= $h($siteHostname) ?></code>
        <?php if (($gitInfo['branch'] ?? '') !== ''): ?> &middot; branch <code><?= $h($gitInfo['branch']) ?></code><?php endif; ?>
        <?php if (($gitInfo['commit'] ?? '') !== ''): ?> &middot; commit <code><?= $h($gitInfo['commit']) ?></code><?php endif; ?>
    </p>
</header>
<main>
    <p>Run <code>ddev install all</code> to (re)install every WordPress instance.</p>
    <?php foreach ($versions as $version):
        $label = str_replace('.', '', $version);
        $path = __DIR__ . '/' . $label;
        $installed = installedVersion($path);
        $url = 'https://' . $label . '.' . $siteHostname;
        $multisite = $installed !== null && str_contains((string) @file_get_contents($path . '/public/wp-config.php'), "'MULTISITE'");
    ?>
        <article>
            <kbd><?= $h($version) ?></kbd>
            <?php if ($installed === null): ?>
                <span>Not installed, run <code>ddev install <?= $h($label) ?></code>.</span>
            <?php else: ?>
                <small><?= $h($installed) ?><?= $multisite ? ' &middot; multisite' : '' ?></small>
                <a target="_blank" href="<?= $h($url) ?>/"><?= $h($url) ?></a>
                <a target="_blank" href="<?= $h($url) ?>/wp-admin/">Admin</a>
                <code>ddev <?= $h($label) ?> wp …</code>
            <?php endif; ?>
        </article>
    <?php endforeach; ?>
    <p>Admin login: <code><?= $h($adminUser) ?></code> / <code><?= $h($adminPassword) ?></code></p>
</main>
</body>
</html>
