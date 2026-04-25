# LOCAL_SETUP.md — host conventions for this Hetzner deployment

This document describes host-specific setup that is NOT captured in the
`Dockerfile` or `docker-compose.yml`. Future Claude Code sessions (and humans)
should read this first before making structural changes.

## Host

- Hetzner server, hostname `openclaw`.
- Sole human user: Karthik. All infra on this box exists to run OpenClaw.

## User accounts

- `root` (uid 0): used for host SSH login. `/root/.ssh/authorized_keys` holds
  Karthik's personal keys.
- `karthik` (uid 1000): the identity OpenClaw runs as. Inside the container
  this uid is labeled `node` (from the `node:24-bookworm` base image). Same
  numeric uid, different label — bind-mounted files are owned by uid 1000
  on both sides of the boundary.
- No other user accounts exist. `suvansh` (the previous owner) was renamed to
  `karthik` on 2026-04-24; nothing should reference `suvansh` any more.

## Paths

- Source repo: `/root/openclaw/` — this git clone, updated with `git pull`.
- Runtime state: `/home/karthik/.openclaw/` — OpenClaw config, workspaces,
  credentials, agent memory, logs. NOT in git; survives rebuilds because it's
  bind-mounted into the container from outside the image.
- The bind mount translates host `/home/karthik/.openclaw/` to container
  `/home/node/.openclaw/`. Inside-container paths are stable; only the host-
  side source path is configurable.

## Configuration knobs

Two env vars in `/root/openclaw/.env` select the host-side bind-mount sources:

```
OPENCLAW_CONFIG_DIR=/home/karthik/.openclaw
OPENCLAW_WORKSPACE_DIR=/home/karthik/.openclaw/workspace
```

If you ever move the state dir, change these two lines and
`docker compose up -d`. Nothing else needs to change — no Dockerfile edits, no
container rebuild. State survives.

## claude-max-api-proxy

The proxy is installed in the image at
`/usr/local/lib/node_modules/claude-max-api-proxy/`, but `proxy-entrypoint.sh`
(the container ENTRYPOINT) overrides that at boot: if
`/home/node/.openclaw/claude-max-api-proxy/` exists on the bind-mounted
volume (host: `/home/karthik/.openclaw/claude-max-api-proxy/`), the entrypoint
symlinks `/home/node/.local/bin/claude-max-api` to it and runs THAT version
before starting the gateway. This is deliberate: `git pull` the proxy repo in
the bind-mounted location, `docker compose restart openclaw-gateway`, and the
new code runs — no image rebuild needed.

Logs: `/home/karthik/.openclaw/logs/claude-max-api.log`.

## Running Claude Code sessions

Always run Claude Code as `karthik`, not `root`. Running as root causes file
ownership drift — every file Claude Code writes becomes root-owned, which
uid 1000 (the container's user) can't then modify. This blocks agents from
editing their own memory, AGENTS.md, and so on.

Aliases in `/root/.bashrc`:

```
alias kclaude='sudo -u karthik -i claude'
alias koc='cd /home/karthik/.openclaw'
```

Workflow: SSH in as root (your keys are on root), then `kclaude` to start a
session as uid 1000. The container, Rocket, Davinci etc. all write as uid
1000; your sessions now match.

## First-time karthik Claude Code authentication

The OAuth token lives in `/root/openclaw/.env` as `CLAUDE_CODE_OAUTH_TOKEN`.
On the first `kclaude` run, either:

1. Re-authenticate interactively (Claude Code will prompt with a URL), OR
2. Copy `/root/.claude/.credentials.json` to `/home/karthik/.claude/.credentials.json`
   and `chown karthik:karthik`, then re-run.

Option 1 is simpler; option 2 reuses the existing token.

## Rebuild workflow

```
cd /root/openclaw
git pull                      # pull repo updates (optional)
docker compose build          # rebuild openclaw:latest from current Dockerfile
docker compose up -d          # recreate containers; picks up .env, remounts state
```

Safe because the image holds only code; all state lives in the bind-mounted
`/home/karthik/.openclaw/`.

## Other running containers on this host

- `cadvisor` (monitoring)
- `node-exporter` (Prometheus metrics)
- Not touched by OpenClaw; unrelated to this deployment.

## History

- 2026-04-24: Renamed host user `suvansh` → `karthik`. Moved state dir from
  `/root/.openclaw/` to `/home/karthik/.openclaw/`. Deleted Suvansh's legacy
  artifacts (`/root/openclaw-old/`, `/home/suvansh/`). Fixed ~1,500 files of
  root-owned ownership drift. Added this doc.
