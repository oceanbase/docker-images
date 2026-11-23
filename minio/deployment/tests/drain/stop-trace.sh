#!/bin/sh
set -eu
touch /work/trace.stop
for f in /proc/[0-9]*/comm; do
 [ "$(cat "$f" 2>/dev/null)" = mc ] || continue
 p=${f#/proc/};p=${p%/comm}
 c=$(tr '\000' ' ' < /proc/$p/cmdline 2>/dev/null || true)
 case "$c" in *'admin trace'*) kill -TERM "$p" 2>/dev/null || true;; esac
done
sleep 2
