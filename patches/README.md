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

Both are written against `v2026.9.11` and are ours to carry. They were offered
upstream and those pull requests were closed on 2026-09-21, so no release will
pick them up: re-check both on every `HERMES_REF` bump. The build fails with the
rejected hunk if either stops applying.

### 0001-webhook-delivery-mirror.patch

Hermes runs a webhook event in its own conversation, which is the
prompt-injection sandbox, and then posts the answer into someone's chat. Nothing
wrote that answer into the receiving chat's transcript, so the agent there had
no record of what it sent, and a follow-up like "make that shorter" had nothing
to resolve against.

The patch mirrors after a successful send, as `role="user"` with a text label
(an assistant-role mirror replays as a real turn and breaks strict-alternation
providers, upstream #2221), with `user_id=None` (the originating turn's user is
`webhook:<route>`, which matches no session in the target chat).

It passes `thread_id=""`, not `None`, when the delivery names no thread. With
`None` the origin lookup applies no thread filter and returns whichever live
session for the chat started most recently, which in a DM that has ever had a
quote-reply is a stale reply thread. That is how the first live test failed on
2026-09-21: the draft went into a two-day-old thread. `""` matches
`COALESCE(thread_id, '') = ''` and selects the main conversation.

Security note: for an inbound-webhook route the mirrored text is model output
derived from untrusted inbound text, written into a chat that may hold the
recipient's own tools. That is a deliberate and narrow widening of the sandbox,
the minimum a reply loop needs for its agent to refer to its own drafts. The
text is framed as a quoted record and capped in length, which is a speed bump
rather than a boundary. Do not widen this to raw event payloads.

### 0002-buzz-dm-replies-stay-in-conversation.patch

Adds a `dm_threads` option to the Buzz platform (`BUZZ_DM_THREADS` or
`extra.dm_threads`, default on, so behaviour is unchanged unless set). Buzz
scopes a session by thread root, in DMs as well as channels, so every
quote-reply in a 1:1 DM opened a new session that had never seen the rest of the
conversation. Replying to a draft with the reply button reached a blank session.
With the option off, a DM reply keeps the main session. The thread root is still
recorded so the agent's answer anchors under the message it replies to, and the
quoted text is still passed along. Channels are unaffected.

Instill's provision writes `BUZZ_DM_THREADS=false` to `.env`.
