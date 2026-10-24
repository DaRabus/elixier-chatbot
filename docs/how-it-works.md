# How it works

## Features

1. **Chat with the internal Ollama model.** Each chat (a 1:1 chat, a channel, a group chat) gets its own conversation
   with its own history.
2. **Escalate to humans.** `/team <text>` forwards a message to the team channel directly. The model can do the same
   with its `notify_team` tool when it decides a person must handle the request.
3. **Let the model act (tool calling).** The model can restart a VM (`vm_command`) or create one (`create_vm`).
   Such dangerous actions are limited to admins and need a "yes" in the chat.
4. **Built-in commands** (handled without the AI):

| Command | Effect |
|---|---|
| `/team <text>` | post `<text>` to the team channel (`TEAM_CHAT_ID`) |
| `/id` | show this chat's id and your user id (needed for configuration) |
| `/reset` | forget the AI conversation history of this chat |

## Architecture

```
                        ┌──────────────────────── Elixir application ─────────────────────────┐
 MS Teams ─► Azure Bot ─►│ Chat.Teams.Plug ─► Teams.Auth (JWT check)                            │
 (or terminal: Console)  │        │                                                            │
                        │        ▼                                                            │
                        │     Router ──► /team, /id, /reset handled directly                   │
                        │        │                                                            │
                        │        ▼                                                            │
                        │  Conversation (1 process per chat) ◄──► Ollama  /api/chat           │
                        │        │  tool_calls                                                │
                        │        ▼                                                            │
                        │  Tools: notify_team · vm_command (ssh) · create_vm (script)         │
                        └─────────────────────────────────────────────────────────────────────┘
```

| Module | File | Responsibility |
|---|---|---|
| `Chatbot.Application` | `lib/chatbot/application.ex` | Starts the Registry, the conversation supervisor and the configured adapter |
| `Chatbot.Chat.Adapter` | `lib/chatbot/chat/adapter.ex` | Behaviour every chat platform implements (`send_message/2`) |
| `Chatbot.Chat.Teams` (+ `Plug`, `Auth`, `State`) | `lib/chatbot/chat/teams*` | Teams webhook, token validation, sending replies |
| `Chatbot.Chat.Console` | `lib/chatbot/chat/console.ex` | Terminal adapter for local development |
| `Chatbot.Message` | `lib/chatbot/message.ex` | Platform-neutral message (`adapter`, `chat_id`, `user_id`, `user_name`, `text`) |
| `Chatbot.Router` | `lib/chatbot/router.ex` | Allowlist check, built-in commands, hands the rest to a Conversation |
| `Chatbot.Conversation` | `lib/chatbot/conversation.ex` | History, tool-calling loop, confirmation of dangerous tools |
| `Chatbot.Ollama` | `lib/chatbot/ollama.ex` | HTTP client for Ollama |
| `Chatbot.Tool` / `Chatbot.Tools` | `lib/chatbot/tool.ex`, `tools.ex` | Tool behaviour and the registry of enabled tools |
| `Chatbot.Shell` | `lib/chatbot/shell.ex` | Runs executables with an argument list and a timeout (no shell) |

## Life of a message

1. A user writes to the bot in Teams. Teams sends the message to the Azure Bot, which calls `POST /api/messages`.
2. `Teams.Auth` verifies Microsoft's JWT (signature, issuer, audience, expiry). Invalid requests get `401`.
3. The plug strips the `@bot` mention, remembers the conversation's service URL, builds a `Chatbot.Message`, passes it
   to the `Router` and answers `200` immediately (Teams expects a fast reply; the AI work is asynchronous).
4. `Router` ignores users outside `ALLOWED_USERS` (if set), handles `/team`, `/id`, `/reset`, and otherwise finds or
   starts the `Conversation` process for that chat and casts the message to it.
5. `Conversation` appends the message to its history and calls Ollama with the history and the tool definitions.
6. **If Ollama answers with text** it is sent back to the chat through the adapter. Done.
7. **If Ollama requests tools**, each one is looked up by name:
   - harmless tool (`dangerous?` is false) -> run it, add the result to the history;
   - dangerous tool -> must come from an admin, then the bot asks "Run X with ...? Reply yes or no." and waits.
     Only that user's "yes" runs it; "no" or any other message cancels it;
   - unknown tool or non-admin -> an error result is fed back to the model.
8. Tool results go back to Ollama (step 5). The loop ends with a text answer or after 8 steps.

Every chat is its own Erlang process, so a slow Ollama call or a crashing tool in one chat never blocks or breaks others.

## State and limits

- History is **in memory**, capped at 40 messages per chat, and lost on restart.
- Teams bot token, Microsoft signing keys and per-conversation service URLs are cached in memory.
- One chat adapter and one Ollama model at a time; answers are not streamed.
