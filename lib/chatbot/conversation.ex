defmodule Chatbot.Conversation do
  @moduledoc """
  One process per chat: keeps the Ollama message history and runs the tool-calling loop.

  Loop: ask Ollama -> if it requests tools, run them, feed results back -> repeat until it
  answers in plain text (max 8 steps).

  Safety: tools with `dangerous?() == true` only run for users listed in `:admins`, and only
  after that same user answers "yes" to a confirmation question in the chat.
  """
  use GenServer, restart: :temporary

  alias Chatbot.{Ollama, Tools}

  @max_steps 8
  @max_history 40
  @max_tool_output 2_000

  def start_link(key), do: GenServer.start_link(__MODULE__, nil, name: {:via, Registry, {Chatbot.Registry, key}})
  def say(pid, msg), do: GenServer.cast(pid, {:say, msg})

  @impl true
  def init(_) do
    system = %{"role" => "system", "content" => Application.fetch_env!(:chatbot, :system_prompt)}
    {:ok, %{history: [system], pending: nil, msg: nil}}
  end

  @impl true
  def handle_cast({:say, msg}, %{pending: nil} = s) do
    {:noreply, %{s | msg: msg} |> add(user_message(msg)) |> step(0)}
  end

  # A tool is waiting for confirmation. Only the requesting user's yes/no counts;
  # anything else cancels it and is processed as a normal message.
  def handle_cast({:say, msg}, %{pending: p} = s) do
    s = %{s | pending: nil, msg: msg}

    case if(msg.user_id == p.user_id, do: answer(msg.text)) do
      :yes -> {:noreply, s |> run_tool(p.mod, p.name, p.args) |> exec_calls(p.rest, p.depth)}
      :no -> {:noreply, s |> add_tool(p.name, "denied by user") |> exec_calls(p.rest, p.depth)}
      nil -> {:noreply, s |> cancel([p.name | rest_names(p.rest)]) |> add(user_message(msg)) |> step(0)}
    end
  end

  defp step(s, depth) when depth >= @max_steps, do: reply(s, "Stopped: too many tool steps.")

  defp step(s, depth) do
    case Ollama.chat(s.history, Tools.specs()) do
      {:ok, %{"tool_calls" => [_ | _] = calls} = m} -> s |> add(m) |> exec_calls(calls, depth)
      {:ok, %{"content" => content} = m} -> s |> add(m) |> reply(content)
      {:error, e} -> reply(s, "Ollama error: #{inspect(e)}")
    end
  end

  defp exec_calls(s, [], depth), do: step(s, depth + 1)

  defp exec_calls(s, [%{"function" => %{"name" => name} = f} | rest], depth) do
    args = f["arguments"] || %{}

    case Tools.fetch(name) do
      nil ->
        s |> add_tool(name, "unknown tool") |> exec_calls(rest, depth)

      mod ->
        cond do
          not mod.dangerous?() ->
            s |> run_tool(mod, name, args) |> exec_calls(rest, depth)

          s.msg.user_id not in Application.get_env(:chatbot, :admins, []) ->
            s |> add_tool(name, "user is not allowed to use this tool") |> exec_calls(rest, depth)

          true ->
            reply(s, "Run #{name} with #{inspect(args)}? Reply yes or no.")
            pending = %{mod: mod, name: name, args: args, rest: rest, depth: depth, user_id: s.msg.user_id}
            %{s | pending: pending}
        end
    end
  end

  defp run_tool(s, mod, name, args) do
    result =
      try do
        mod.run(args, s.msg)
      rescue
        e -> {:error, Exception.message(e)}
      end

    text = case result do
      {:ok, t} -> t
      {:error, t} -> "error: " <> t
    end

    add_tool(s, name, String.slice(text, 0, @max_tool_output))
  end

  defp cancel(s, names), do: Enum.reduce(names, s, &add_tool(&2, &1, "cancelled"))
  defp rest_names(calls), do: Enum.map(calls, & &1["function"]["name"])

  defp answer(text) do
    case text |> String.trim() |> String.downcase() do
      t when t in ["yes", "y", "ja"] -> :yes
      t when t in ["no", "n", "nein"] -> :no
      _ -> nil
    end
  end

  defp user_message(msg), do: %{"role" => "user", "content" => "#{msg.user_name}: #{msg.text}"}
  defp add_tool(s, name, content), do: add(s, %{"role" => "tool", "tool_name" => name, "content" => content})

  # ponytail: plain sliding window; may cut a tool exchange in half, summarize old turns if that bites.
  defp add(%{history: [system | rest]} = s, m), do: %{s | history: [system | Enum.take(rest ++ [m], -@max_history)]}

  defp reply(s, text) do
    s.msg.adapter.send_message(s.msg.chat_id, text)
    s
  end
end
