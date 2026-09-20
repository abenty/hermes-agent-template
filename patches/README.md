# Patches

Patch files in this directory are applied to the cloned `hermes-agent` source
during the image build, after the clone and before the editable install. The
Dockerfile loop applies each `*.patch` in filename order and fails the build if
any one of them does not apply.

Each patch is written against the exact ref in `ARG HERMES_REF`. It is not
written against any local checkout. To produce one:

```sh
git clone --depth 1 --branch <HERMES_REF> \
  https://github.com/NousResearch/hermes-agent.git /tmp/hermes
cd /tmp/hermes
# edit, then:
git diff > /path/to/patches/00NN-short-name.patch
```

A patch that stops applying after a `HERMES_REF` bump fails the build with the
rejected hunk in the log. Rebase it against the new ref, or delete it if
upstream has merged the change.

## Why patches and not a Hermes fork

A fork of `hermes-agent` would have to be kept in sync with every upstream
release for what is usually a few lines of change. A patch file states the
change and nothing else, and it announces its own staleness by failing to apply.

## Current patches

### 0001-webhook-delivery-mirror.patch

Written against `v2026.9.11`. Filed upstream; delete this file once a release
carries it.

Hermes runs a webhook event in its own conversation, which is the
prompt-injection sandbox, and then posts the answer into someone's chat. Nothing
writes that answer into the receiving chat's transcript, so the agent there has
no record of what it sent. A follow-up like "make that shorter" has nothing to
resolve against, and the model picks the nearest plausible thing in its own
history instead. We saw it shorten an unrelated month-old message.

The `send_message` tool already mirrors, and cron mirrors when
`cron.mirror_delivery` is set. Webhook delivery was the one path that did not.

The patch captures the send result and mirrors only when the send succeeded. It
mirrors as `role="user"`, because an assistant-role mirror replays as a real turn
and produces assistant-to-assistant pairs that break strict-alternation
providers (upstream #2221). Authorship is carried by a text label instead. It
passes `user_id=None`, because the originating turn's user is `webhook:<route>`,
which matches no session in the target chat and would make the origin scan bail.

Security note: for an inbound-webhook route the mirrored text is model output
derived from untrusted inbound text, written into a chat that may hold the
recipient's own tools. That is a deliberate and narrow widening of the sandbox,
and it is the minimum needed for a reply loop whose agent can refer to its own
drafts. The text is framed as a quoted record and capped in length, which is a
speed bump rather than a boundary. Do not widen this to raw event payloads.
