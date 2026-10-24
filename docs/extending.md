# Extending the bot

## Add a tool

A tool is a module implementing `Chatbot.Tool`:

| Callback | Purpose |
|---|---|
| `name/0` | snake_case name the model calls |
| `description/0` | tells the model **when** to use it - the most important line for good behavior |
| `parameters/0` | JSON schema of the arguments |
| `dangerous?/0` | `true` = admins only + yes/no confirmation in chat |
| `run/2` | `run(args, message)` returns `{:ok, text}` or `{:error, text}`; the text goes back to the model, not to the user |

```elixir
defmodule Chatbot.Tools.DiskUsage do
  @behaviour Chatbot.Tool
  def name, do: "disk_usage"
  def description, do: "Show disk usage of the bot host."
  def parameters, do: %{type: "object", properties: %{}}
  def dangerous?, do: false
  def run(_args, _ctx), do: Chatbot.Shell.run("df", ["-h"])
end
```

Then add it to `:tools` in `config/config.exs`. No other wiring.

Guidelines:
- Validate every argument in `run/2`; the model's output is untrusted input.
- Use `Chatbot.Shell.run/3` (argument list, timeout) instead of building shell strings.
- Prefer allowlists and named actions over free-form input (see `vm_command`).
- Anything that changes infrastructure should be `dangerous?: true`.
- Add a small test like `test/tools_test.exs`.

New named VM commands need no code: add them to `:vm_commands` in `config/config.exs`.
For VM creation, the real work lives in `CREATE_VM_SCRIPT`, so changing hypervisor means changing a script, not Elixir.

## Add a chat platform

Implement `Chatbot.Chat.Adapter`:

1. A supervised process (GenServer, Supervisor, Task) that receives platform events and builds
   `%Chatbot.Message{adapter: __MODULE__, chat_id: ..., user_id: ..., user_name: ..., text: ...}` (ids as strings),
   then calls `Chatbot.Router.handle/1`. Return quickly - the router does not block.
2. `send_message(chat_id, text)` to answer.
3. Add a branch for it in `config/runtime.exs` (`CHAT_ADAPTER=...` plus its credentials).

`lib/chatbot/chat/teams.ex` is the full example, `lib/chatbot/chat/console.ex` the minimal one.

## Change the AI behavior

- System prompt: `:system_prompt` in `config/config.exs`.
- Model/endpoint: `OLLAMA_MODEL`, `OLLAMA_URL`.
- History size and max tool steps per request: module attributes in `lib/chatbot/conversation.ex`.

## Ideas when you outgrow the defaults

- Persist history (ETS/SQLite/Postgres) if restarts losing context hurts.
- Stream tokens (`stream: true`) and update the Teams message while generating.
- Several adapters at once: make `:adapter` a list in `application.ex`.
- Audit log of tool executions (who confirmed what) - add it in `Conversation.run_tool/4`.
