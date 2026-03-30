#!/bin/bash
# This script is used by CI to build all test functions

SCRIPT_DIR=$(dirname "$0")
TEST_FUNCTIONS=$(
    grep -oE 'void[[:space:]]+test_[A-Za-z0-9_]+[[:space:]]*\(' src/test/test.c \
    | sed -E 's/void[[:space:]]+//; s/[[:space:]]*\(//' \
    | sort -u
)

for test_function in $TEST_FUNCTIONS; do
    make HW=LAUNCHPAD TEST=$test_function
    make HW=NSUMO TEST=$test_function
done