#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"

target="$script_dir/macos/AdobeBackuper.command"
chmod +x "$target" || true
open "$target"

