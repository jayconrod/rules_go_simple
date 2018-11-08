#!/bin/bash

# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

set -euo pipefail

program="$1"
got=$("$program")
want=(foo.txt bar.txt)

for w in "${want[@]}"; do
  if [[ $got != *$w* ]]; then
    echo $got >&2
    echo "error: program output does not contain $w" >&2
    exit 1
  fi
done
