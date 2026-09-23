#!/bin/sh
# Bring the workspace template on the volume to the tip of its branch, then run
# provision so what runs is what is installed. Run over `railway ssh`, which sees
# the service's variables:  sh /app/update-template.sh   (--no-provision to skip)
#
# Provision runs detached (setsid + nohup) and writes to a log on the volume;
# this script only follows that log. A dropped ssh session used to kill
# provision silently right after the "template:" line, leaving the new template
# on disk but the old hook and plugin installed. Now provision always finishes,
# and the log's last line says how: "provision: done" or "provision: FAILED".
set -eu
TPL=${INSTILL_TEMPLATE_DIR:-/data/instill-workspace-template}
RUN_PROVISION=${INSTILL_RUN_PROVISION:-/data/.hermes/scripts/run-provision.sh}
LOG_DIR=${INSTILL_PROVISION_LOG_DIR:-/data/.hermes/logs}
[ -n "${INSTILL_TEMPLATE_TOKEN:-}" ] || { echo "INSTILL_TEMPLATE_TOKEN is not set on this service" >&2; exit 2; }
[ -d "$TPL/.git" ] || { echo "$TPL is not a git checkout yet; restart the service once so start.sh clones it" >&2; exit 2; }
AUTH=$(printf 'x-access-token:%s' "$INSTILL_TEMPLATE_TOKEN" | base64 | tr -d '\n')
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.extraheader GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $AUTH" GIT_TERMINAL_PROMPT=0
BEFORE=$(git -C "$TPL" rev-parse --short HEAD)
git -C "$TPL" fetch -q origin "${INSTILL_TEMPLATE_BRANCH:-master}"
git -C "$TPL" reset -q --hard FETCH_HEAD
echo "template: $BEFORE -> $(git -C "$TPL" log --oneline -1)"
[ "${1:-}" = "--no-provision" ] && exit 0
# The token has done its job; provision never needs it.
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 AUTH
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/provision-$(date -u +%Y%m%dT%H%M%SZ).log"
ln -sf "$LOG" "$LOG_DIR/provision-last.log"
echo "provision: running detached, log $LOG"
setsid nohup sh -c 'if sh "$1"; then echo "provision: done"; else echo "provision: FAILED (exit $?)"; fi' \
  provision "$RUN_PROVISION" >"$LOG" 2>&1 </dev/null &
PID=$!
# Follow the log until provision exits. If this session drops, only the tail
# dies; provision carries on. Check later with: tail -n 1 $LOG_DIR/provision-last.log
tail -n +1 --pid="$PID" -f "$LOG" || true
tail -n 1 "$LOG" | grep -qx "provision: done"
