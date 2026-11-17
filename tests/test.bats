#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# To exclude the end-to-end install (downloads WordPress):
#   bats ./tests/test.bats --filter-tags '!install'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=portrino/ddev-wordpress-multi-version-plugin

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"

  printf '<?php\n/**\n * Plugin Name: Test Plugin\n */\n' > test-plugin.php
  printf '{"name": "test/test-plugin", "type": "wordpress-plugin"}\n' > composer.json
}

start_project() {
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site --webserver-type="$1"
  assert_success
  run ddev start -y
  assert_success
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
}

# <label>.<project> serves .Build/<label>/public, existing files directly, core paths
# from public/wp-source, the rest via index.php
routing_checks() {
  mkdir -p "${TESTDIR}/.Build/71/public/second-dir" "${TESTDIR}/.Build/71/public/wp-source/wp-admin"
  echo "WP71" > "${TESTDIR}/.Build/71/public/marker.txt"
  echo '<?php echo "INDEX71";' > "${TESTDIR}/.Build/71/public/index.php"
  echo '<?php echo "LOGIN71";' > "${TESTDIR}/.Build/71/public/wp-source/wp-login.php"
  echo '<?php echo "ADMIN71";' > "${TESTDIR}/.Build/71/public/wp-source/wp-admin/index.php"

  run curl -sfk "https://71.${PROJNAME}.ddev.site/wp-login.php"
  assert_output "LOGIN71"
  run curl -sfk "https://71.${PROJNAME}.ddev.site/subsite/wp-admin/"
  assert_output "ADMIN71"

  run curl -sfk "https://71.${PROJNAME}.ddev.site/marker.txt"
  assert_success
  assert_output "WP71"

  run curl -sfk "https://71.${PROJNAME}.ddev.site/some/pretty/permalink/"
  assert_success
  assert_output "INDEX71"

  # Directory without slash: redirect stays on https
  run curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "https://71.${PROJNAME}.ddev.site/second-dir"
  assert_output --regexp '^301 (https://71\.'"${PROJNAME}"'\.ddev\.site)?/second-dir/$'
}

generated_files_checks() {
  assert_file_exist .ddev/config.wordpress-setup.yaml
  run grep -F "71.${PROJNAME}" .ddev/config.wordpress-setup.yaml
  assert_success
  assert_file_exist .ddev/commands/web/64
  assert_file_exist .ddev/commands/web/71
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory (apache-fpm)" {
  set -eu -o pipefail
  start_project apache-fpm
  generated_files_checks
  routing_checks
}

@test "install from directory (nginx-fpm)" {
  set -eu -o pipefail
  start_project nginx-fpm
  generated_files_checks
  routing_checks
}

@test "WP_VERSIONS override regenerates hostnames and commands" {
  set -eu -o pipefail
  mkdir -p .ddev
  printf 'services:\n  web:\n    environment:\n      - WP_VERSIONS=7.0\n' > .ddev/docker-compose.zz-project.yaml
  start_project apache-fpm
  assert_file_exist .ddev/commands/web/70
  assert_file_not_exist .ddev/commands/web/64
  run grep -F "70.${PROJNAME}" .ddev/config.wordpress-setup.yaml
  assert_success
}

@test "remove cleans up generated files" {
  set -eu -o pipefail
  start_project apache-fpm
  run ddev add-on remove wordpress-multi-version-plugin
  assert_success
  assert_file_not_exist .ddev/config.wordpress-setup.yaml
  assert_file_not_exist .ddev/commands/web/71
  assert_file_not_exist .ddev/apache/wordpress-versions.conf
}

# bats test_tags=install
@test "install a WordPress instance and activate the plugin" {
  set -eu -o pipefail
  start_project apache-fpm
  run ddev install 6.4 --multisite
  assert_success
  run ddev 64 wp core version
  assert_output --regexp '^6\.4\.[0-9]+$'
  run ddev 64 wp plugin is-active test-plugin --network
  assert_success
  # The plugin comes from the path repository, its symlinks point back to the project root
  assert_link_exists .Build/64/packages/test-plugin/test-plugin.php
  run curl -sfk "https://64.${PROJNAME}.ddev.site/wp-login.php"
  assert_success
  run curl -sfk -o /dev/null -w '%{http_code}' "https://64.${PROJNAME}.ddev.site/"
  assert_output "200"
  # A second plugin keeps its own basename, the symlinked plugin doesn't swallow it
  run ddev 64 wp plugin install hello-dolly --activate-network --quiet
  assert_success
  printf '<?php echo plugin_basename(WP_PLUGIN_DIR . "/hello-dolly/hello.php");' > check.php
  run ddev exec "cd .Build/64 && wp eval-file /var/www/html/check.php 2>/dev/null"
  assert_output "hello-dolly/hello.php"
  run ddev 64 wp site create --slug=second --quiet
  assert_success
  run curl -sfk "https://64.${PROJNAME}.ddev.site/second/wp-login.php"
  assert_success
}

# bats test_tags=install
@test "single site: admin login works under /wp-admin/" {
  set -eu -o pipefail
  start_project nginx-fpm
  run ddev install 7.1
  assert_success
  base="https://71.${PROJNAME}.ddev.site"
  jar="${TESTDIR}/cookies"
  curl -sk -o /dev/null -c "$jar" -b "$jar" "$base/wp-login.php"
  run curl -sk -o /dev/null -w '%{http_code}' -c "$jar" -b "$jar" \
    --data-urlencode log=admin --data-urlencode 'pwd=Password1!' --data-urlencode testcookie=1 "$base/wp-login.php"
  assert_output "302"
  run curl -sk -o /dev/null -w '%{http_code}' -b "$jar" "$base/wp-admin/plugins.php"
  assert_output "200"
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site --webserver-type=apache-fpm
  assert_success
  run ddev start -y
  assert_success
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  generated_files_checks
}
