#!/bin/sh
# Bring the workspace template on the volume to the tip of its branch, then run
# provision so what runs is what is installed. Run over `railway ssh`, which sees
# the service's variables:  sh /app/update-template.sh   (--no-provision to skip)
set -eu
TPL=/data/instill-workspace-template
[ -n "${INSTILL_TEMPLATE_TOKEN:-}" ] || { echo "INSTILL_TEMPLATE_TOKEN is not set on this service" >&2; exit 2; }
[ -d "$TPL/.git" ] || { echo "$TPL is not a git checkout yet; restart the service once so start.sh clones it" >&2; exit 2; }
AUTH=$(printf 'x-access-token:%s' "$INSTILL_TEMPLATE_TOKEN" | base64 | tr -d '\n')
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.extraheader GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $AUTH" GIT_TERMINAL_PROMPT=0
BEFORE=$(git -C "$TPL" rev-parse --short HEAD)
git -C "$TPL" fetch -q origin "${INSTILL_TEMPLATE_BRANCH:-master}"
git -C "$TPL" reset -q --hard FETCH_HEAD
echo "template: $BEFORE -> $(git -C "$TPL" log --oneline -1)"
[ "${1:-}" = "--no-provision" ] && exit 0
exec sh /data/.hermes/scripts/run-provision.sh
