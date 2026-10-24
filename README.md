# Team Chatbot (Elixir)

Internal chat bot that sits between people and our infrastructure:

1. **Chat with our Ollama model** - every conversation has its own history.
2. **Escalate to humans** - `/team <text>` or the model's `notify_team` tool posts into the team chat.
3. **Let the model act** - tool calling: restart a VM over ssh, create a VM, anything you add.

```
MS Teams / Console ──► Router ──► Conversation (1 process per chat) ──► Ollama /api/chat
   (Chat.Adapter)       │             │  tool_calls ▲
                        │             ▼             │ results
                        └─ /team  ──► Tools (NotifyTeam, VmCommand, CreateVm, ...)
```

| Piece | File | Job |
|---|---|---|
| Adapter | `lib/chatbot/chat/*.ex` | Talks to a chat platform. MS Teams (Bot Framework webhook) + Console (dev). |
| Router | `lib/chatbot/router.ex` | Allowlist check, `/team`, `/reset`, else hands over to the AI. |
| Conversation | `lib/chatbot/conversation.ex` | History + tool loop + confirmation of dangerous tools. |
| Tools | `lib/chatbot/tools/*.ex` | What the AI may do. |
| Config | `config/config.exs`, `config/runtime.exs` | Static defaults / environment variables. |

> Full documentation: [docs/](docs/README.md)

## Setup

```bash
# 1. Install Erlang + Elixir (versions in .tool-versions), e.g. with mise or asdf:
mise install            # or: asdf install

# 2. Dependencies, tests
mix deps.get
mix test

# 3. Ollama with a tool-capable model
ollama pull llama3.1

# 4. Try it in the terminal
cp .env.example .env    # edit, then:
set -a; source .env; set +a
ADMINS=console mix run --no-halt
```

### MS Teams

Teams delivers messages to a public HTTPS webhook, so the bot runs a small web server (`PORT`, default 3978).

1. **Azure**: create an *Azure Bot* resource (type **Single Tenant**) with a new Entra app registration; note
   *Application (client) ID* -> `TEAMS_APP_ID`, *Directory (tenant) ID* -> `TEAMS_TENANT_ID`, and create a
   client secret -> `TEAMS_APP_SECRET`.
2. **Messaging endpoint** of the bot: `https://<public-host>/api/messages` (TLS via reverse proxy such as nginx/Caddy;
   for local development use a tunnel, e.g. `devtunnel host -p 3978 --allow-anonymous` or ngrok).
3. Enable the **Microsoft Teams channel** on the Azure Bot resource.
4. **Teams app**: create a manifest (Developer Portal -> Apps) with the bot id = `TEAMS_APP_ID`, scopes
   *personal*, *team*, *groupChat*; upload it (sideload) to your tenant or publish it in the org catalog.
5. Start the bot with `CHAT_ADAPTER=teams`, open a 1:1 chat with it and send `/id` to get your user id -> `ADMINS`.
6. Add the bot to the team channel, @mention it with `/id` to get the channel's conversation id -> `TEAM_CHAT_ID`
   (cut everything after `;` if present, otherwise escalations post into that thread). Set `TEAMS_SERVICE_URL`
   to the `serviceUrl` region of your tenant (default `https://smba.trafficmanager.net/emea/`).

In channels and group chats Teams only sends messages that @mention the bot; in 1:1 chats every message arrives.
Every incoming request is verified against Microsoft's signing keys (`Chatbot.Chat.Teams.Auth`).

Production: `MIX_ENV=prod mix release`, run `_build/prod/rel/chatbot/bin/chatbot start` under systemd with the
variables from `.env.example` as the environment.

## Configuration

| Variable | Meaning |
|---|---|
| `CHAT_ADAPTER` | `console` (default) or `teams` |
| `OLLAMA_URL`, `OLLAMA_MODEL` | Ollama endpoint and model (must support tools) |
| `TEAMS_APP_ID`, `TEAMS_APP_SECRET`, `TEAMS_TENANT_ID` | Azure Bot / Entra app credentials |
| `TEAMS_SERVICE_URL`, `PORT` | Fallback Bot Framework service URL; webhook port |
| `TEAM_CHAT_ID` | Teams conversation id where escalations land |
| `ALLOWED_USERS` | Comma separated user ids allowed to talk to the bot (empty = all) |
| `ADMINS` | User ids allowed to trigger dangerous tools |
| `VM_HOSTS` | ssh targets (`user@host`) the `vm_command` tool may use |
| `CREATE_VM_SCRIPT` | Executable called as `script <name> <user_id>` by `create_vm` |

Named VM commands, the system prompt and the enabled tool list are in `config/config.exs`.

## Security model (read before enabling VM tools)

The model is not trusted - its output is treated like user input.

- Tools flagged `dangerous?` run only for **`ADMINS`** and only after that user answers **yes** in chat.
  Any other message cancels the pending action.
- The model never provides shell text: `vm_command` picks a *name* from `:vm_commands` and a host from `VM_HOSTS`;
  processes are started with argument lists (no shell), with timeouts (`Chatbot.Shell`).
- `create_vm` validates the VM name; the script is where quotas/limits belong.
- Give the bot's OS user a dedicated ssh key and restrict it on the VM side (sudoers entry for
  `systemctl reboot` only). Keep `ALLOWED_USERS` set for anything internet-reachable.

## Extending

**New tool** - implement `Chatbot.Tool` and list it under `:tools` in `config/config.exs`:

```elixir
defmodule Chatbot.Tools.Uptime do
  @behaviour Chatbot.Tool
  def name, do: "uptime"
  def description, do: "Show uptime of the bot host."
  def parameters, do: %{type: "object", properties: %{}}
  def dangerous?, do: false
  def run(_args, _ctx), do: Chatbot.Shell.run("uptime", [])
end
```

**New chat platform** (Slack, Matrix, Mattermost, ...) - implement `Chatbot.Chat.Adapter`: a supervised process
that builds a `%Chatbot.Message{}` and calls `Chatbot.Router.handle/1`, plus `send_message/2`.
Use `lib/chatbot/chat/teams.ex` as the template, then map it in `config/runtime.exs`.

**Known limits (deliberate, upgrade when needed)**
- History is in memory only (lost on restart); capped at 40 messages per chat.
- Teams service URLs per conversation and the bot token are cached in memory only.
- One adapter at a time; one Ollama model for everything.
- No streaming of tokens; answers arrive when complete.
- Code was written without a local Elixir toolchain and never run against a real Azure Bot - run `mix test` first and report compile errors or auth problems.
