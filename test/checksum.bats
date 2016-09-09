#!/usr/bin/env bats

load test_helper
export RUBY_BUILD_SKIP_MIRROR=1
export RUBY_BUILD_CACHE_PATH=
export RUBY_BUILD_ARIA2_OPTS=


@test "package URL without checksum" {
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/without-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
}


@test "package URL with valid checksum" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub shasum
}


@test "package URL with invalid checksum" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-invalid-checksum

  assert_failure
  refute [ -f "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub shasum
}


@test "package URL with checksum but no shasum support" {
  stub shasum false
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub shasum
}


@test "package URL with valid md5 checksum" {
  stub md5 true "echo 83e6d7725e20166024a1eb74cde80677"
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-md5-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub md5
}


@test "package URL with md5 checksum but no md5 support" {
  stub md5 false
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-md5-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub md5
}


@test "package with invalid checksum" {
  stub shasum true "echo invalid"
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  install_fixture definitions/with-checksum

  assert_failure
  refute [ -f "${INSTALL_ROOT}/bin/package" ]

  unstub aria2c
  unstub shasum
}

@test "existing tarball in build location is reused" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub aria2c false
  stub wget false

  export -n RUBY_BUILD_CACHE_PATH
  export RUBY_BUILD_BUILD_PATH="${TMP}/build"

  mkdir -p "$RUBY_BUILD_BUILD_PATH"
  ln -s "${FIXTURE_ROOT}/package-1.0.0.tar.gz" "$RUBY_BUILD_BUILD_PATH"

  run_inline_definition <<DEF
install_package "package-1.0.0" "http://example.com/packages/package-1.0.0.tar.gz#ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5" copy
DEF

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub shasum
}

@test "existing tarball in build location is discarded if not matching checksum" {
  stub shasum true \
    "echo invalid" \
    "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  export -n RUBY_BUILD_CACHE_PATH
  export RUBY_BUILD_BUILD_PATH="${TMP}/build"

  mkdir -p "$RUBY_BUILD_BUILD_PATH"
  touch "${RUBY_BUILD_BUILD_PATH}/package-1.0.0.tar.gz"

  run_inline_definition <<DEF
install_package "package-1.0.0" "http://example.com/packages/package-1.0.0.tar.gz#ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5" copy
DEF

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub shasum
}

@test "package URL with checksum of unexpected length" {
  stub aria2c "-o * http://example.com/* : cp $FIXTURE_ROOT/\${3##*/} \$2"

  run_inline_definition <<DEF
install_package "package-1.0.0" "http://example.com/packages/package-1.0.0.tar.gz#checksum_of_unexpected_length" copy
DEF

  assert_failure
  refute [ -f "${INSTALL_ROOT}/bin/package" ]
  assert_output_contains "unexpected checksum length: 29 (checksum_of_unexpected_length)"
  assert_output_contains "expected 0 (no checksum), 32 (MD5), or 64 (SHA2-256)"
}
