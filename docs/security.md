# Security model

The bot can run commands on your infrastructure, so assume the model can be manipulated (prompt injection through user
text) and treat its output like user input.

## Layers

| Layer | What it prevents |
|---|---|
| JWT validation of every Teams request (`Teams.Auth`) | forged messages from anyone who finds the webhook URL |
| `ALLOWED_USERS` | unknown users chatting with the bot at all (empty = everyone in your tenant who can reach the bot) |
| `ADMINS` | normal users triggering dangerous tools |
| Confirmation (yes/no) by the same user | the model acting on its own or on injected text; any other message cancels the action |
| Named commands + host allowlist (`vm_command`) | the model inventing shell commands or targets |
| Argument lists, no shell, timeouts (`Chatbot.Shell`) | shell injection and hanging processes |
| Name validation in `create_vm` | injection through VM names; quotas belong in the script |

## Hardening checklist

- Give the bot its own OS user and ssh key; on the VMs allow only what is needed, e.g. a sudoers line for
  `systemctl reboot`, not full sudo.
- Keep `vm_commands` small; every entry is something the model can ask an admin to approve.
- Set `ALLOWED_USERS` and restrict the Teams app to the people who need it (Teams admin center).
- Keep secrets (`TEAMS_APP_SECRET`) in the service environment, never in git (`.env` is git-ignored). Rotate the secret before it expires.
- Expose only the `/api/messages` path through the reverse proxy.
- Confirmation shows the tool name and arguments - read them before answering "yes".

## Known gaps

- No audit log yet (see [extending.md](extending.md)).
- Anyone in a channel can read what the bot prints, including tool output summaries the model repeats.
- History is sent to Ollama as-is; do not paste secrets into the chat.
