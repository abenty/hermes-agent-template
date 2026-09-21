# Why this fork exists

This is a fork of [`praveen-ks-2001/hermes-agent-template`](https://github.com/praveen-ks-2001/hermes-agent-template),
the Railway deploy template for Hermes Agent. Instill runs customer engine
instances from it.

We forked it for two reasons.

We need to carry changes to `hermes-agent` before upstream merges them. The
template's Dockerfile clones `NousResearch/hermes-agent` from a hardcoded URL at
a `HERMES_REF` build arg, so setting `HERMES_REF` as a Railway variable can only
select a ref that NousResearch publishes. It cannot point at our own code. The
only alternative we had was editing files on the running container, where a
stale edit fails silently at runtime and every redeploy reverts it. We lost a
WhatsApp fix that way.

We also should not deploy customer instances from a third party's `main`. The
upstream template is public and we have read access to it, so any push there
reaches our next rebuild without us doing anything.

## What is different from upstream

One addition: `COPY patches/ /opt/instill-patches/`, and a loop in the clone
step that applies every patch before the editable install. See
`patches/README.md`. With an empty `patches/` directory the build is identical
to upstream.

## Keeping up with upstream

```sh
git remote add upstream https://github.com/praveen-ks-2001/hermes-agent-template.git
git fetch upstream
git rebase upstream/main
```

Our change touches a few lines of the Dockerfile, so conflicts should be rare
and obvious. After a rebase that moves `HERMES_REF`, rebuild once and read the
log: a patch written against the old ref will fail to apply and stop the build.
That failure is the point of keeping patches as files.

## The workspace template

Instill's provision runs from `/opt/instill-workspace-template`. That path used
to be a copy on the container, so every redeploy deleted it and someone had to
push the files back by hand. The template now lives on the volume at
`/data/instill-workspace-template`, and `start.sh` links it back at every start.

If the service has `INSTILL_TEMPLATE_TOKEN` (a fine-grained GitHub token with
read-only Contents access to that one repository), `start.sh` also clones the
template the first time it finds a copy that is not a git checkout. It never
updates an existing checkout at startup, because what runs should be what
provision installed. A failed clone keeps the existing copy, and nothing in the
step can stop the gateway from starting.

To update the template on a running instance:

```sh
railway ssh -s "Hermes Agent" "sh /app/update-template.sh"
```

That fetches the tip of `master`, resets the checkout to it and runs provision.
Pass `--no-provision` to fetch without installing. The token reaches git
through `GIT_CONFIG_*` environment variables rather than the command line, so it
does not show up in the process list, and the agent's own shell starts from an
empty environment and cannot read it.

## Deployment

Railway service "Hermes Agent" in project `hermes-bluetuffy` builds from this
repo. The commit it is running is visible on the container as
`RAILWAY_GIT_COMMIT_SHA`, alongside `RAILWAY_GIT_REPO_OWNER` and
`RAILWAY_GIT_REPO_NAME`, which is the quickest way to confirm which build any
instance is actually on.
