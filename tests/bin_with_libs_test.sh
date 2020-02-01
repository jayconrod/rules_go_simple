#!/bin/bash

# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

set -euo pipefail

program="$1"
got=$("$program")
want="foo
bar
baz
baz"

if [ "$got" != "$want" ]; then
  cat >&2 <<EOF
got:
$got

want:
$want
EOF
  exit 1
fi
