#!/usr/bin/env bash
#ddev-generated
# Prints WP_VERSIONS on the host, where the container environment isn't available
# (install.yaml, ddev worktree-init). The project-owned docker-compose.zz-project.yaml
# wins over the add-on's default, like it does in the container.
# Usage: wp-versions-host.sh <project root>

ddev_dir="${1:?project root}/.ddev"
wp_versions=""
for file in "$ddev_dir/docker-compose.zz-project.yaml" "$ddev_dir/docker-compose.wordpress-setup.yaml"; do
    if [ -f "$file" ]; then
        wp_versions=$(grep -oE 'WP_VERSIONS=[0-9. ]+' "$file" | head -n1 | cut -d= -f2)
    fi
    [ -n "$wp_versions" ] && break
done
if [ -z "$wp_versions" ]; then
    echo "No WP_VERSIONS found in $ddev_dir/docker-compose.wordpress-setup.yaml." >&2
    exit 1
fi
for version in $wp_versions; do
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid WordPress version '$version' in WP_VERSIONS, use <major>.<minor>, e.g. 7.1." >&2
        exit 1
    fi
done
echo $wp_versions
