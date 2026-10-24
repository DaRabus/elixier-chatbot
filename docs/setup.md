# Setup and running

## Requirements

| What | Why |
|---|---|
| Erlang/OTP 27 + Elixir 1.18 (see `.tool-versions`; Elixir >= 1.15 works) | runs the app. Install with `mise install` or `asdf install` |
| An Ollama server with a **tool-capable** model (e.g. `llama3.1`, `qwen2.5`) | the AI. `ollama pull llama3.1` |
| For Teams: an Azure subscription/tenant where you can create an Azure Bot and an Entra app registration | chat platform, see [teams.md](teams.md) |
| For Teams: a public HTTPS URL pointing to the bot's port | Teams can only call public endpoints (reverse proxy or tunnel) |
| For VM tools: key-based ssh from the bot host to the VMs; a script for VM creation | see [security.md](security.md) |

## Configuration (environment variables)

| Variable | Required | Meaning |
|---|---|---|
| `CHAT_ADAPTER` | no | `console` (default) or `teams` |
| `OLLAMA_URL` | no | default `http://localhost:11434` |
| `OLLAMA_MODEL` | no | default `llama3.1` |
| `TEAMS_APP_ID`, `TEAMS_APP_SECRET`, `TEAMS_TENANT_ID` | for `teams` | from the Azure Bot / Entra app |
| `TEAMS_SERVICE_URL` | no | fallback Bot Framework URL for proactive posts, default region EMEA: `https://smba.trafficmanager.net/emea/` |
| `PORT` | no | webhook port, default `3978` |
| `TEAM_CHAT_ID` | for escalation | Teams conversation id of the team channel (use `/id`) |
| `ALLOWED_USERS` | no | comma separated user ids allowed to chat; empty = everyone |
| `ADMINS` | for VM tools | comma separated user ids allowed to trigger dangerous tools |
| `VM_HOSTS` | for `vm_command` | comma separated ssh targets, e.g. `ops@vm1.internal,ops@vm2.internal` |
| `CREATE_VM_SCRIPT` | for `create_vm` | executable called as `script <vm-name> <requesting-user-id>` |

Static settings (system prompt, named VM commands, enabled tools) are in `config/config.exs`.
`.env.example` lists everything; copy it to `.env` (git-ignored).

## Run locally (terminal, no Teams needed)

```bash
mix deps.get
mix test
cp .env.example .env            # adjust OLLAMA_*; leave CHAT_ADAPTER=console
set -a; source .env; set +a
ADMINS=console mix run --no-halt
```

Type a message and press Enter; answers are printed as `bot> ...`. `ADMINS=console` lets you try the dangerous tools.

## Run with Teams

1. Complete [teams.md](teams.md) and fill in the `TEAMS_*` variables, `CHAT_ADAPTER=teams`.
2. `mix run --no-halt` (dev) - the bot listens on `PORT`; expose it via your tunnel/reverse proxy.
3. Write to the bot in Teams. Send `/id` to learn your user id, put it into `ADMINS`, restart.

## Production

```bash
MIX_ENV=prod mix release
_build/prod/rel/chatbot/bin/chatbot start
```

Run it under systemd (or a container) with the variables from `.env.example` as environment, restart on failure, and put a
TLS-terminating reverse proxy (nginx, Caddy) in front of `PORT`. The bot user's ssh key must be able to log in to `VM_HOSTS`.

## Troubleshooting

| Symptom | Check |
|---|---|
| Teams shows no answer, nothing in logs | Azure Bot messaging endpoint URL; tunnel/proxy reaches `PORT` |
| `401` on `/api/messages` | `TEAMS_APP_ID` must equal the bot's app id; server clock must be correct |
| Bot receives but cannot answer | `TEAMS_APP_SECRET` / `TEAMS_TENANT_ID`; log line with `{:token, ...}` |
| `Ollama error` in chat | `OLLAMA_URL` reachable from the bot host; model pulled; model supports tools |
| "user is not allowed to use this tool" | your id (see `/id`) missing in `ADMINS` |
| Escalation fails with `unknown_service_url` | set `TEAMS_SERVICE_URL`; bot must be added to the team channel |
