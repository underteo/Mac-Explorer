#!/bin/sh
# Sample Mac Explorer plugin handler (out of process).
action="$1"
shift
logfile="${TMPDIR:-/tmp}/mac-explorer-sample-plugin.log"
{
  echo "action=$action"
  for path in "$@"; do
    echo "path=$path"
  done
} >> "$logfile"
exit 0
