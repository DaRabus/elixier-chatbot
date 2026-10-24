defmodule Chatbot.Chat.Teams.State do
  @moduledoc "In-memory cache for the Teams adapter: bot token, Microsoft signing keys, service URL per conversation."
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)
  def get(key), do: Agent.get(__MODULE__, &Map.get(&1, key))
  def put(key, value), do: Agent.update(__MODULE__, &Map.put(&1, key, value))
end
