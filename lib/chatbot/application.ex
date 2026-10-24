defmodule Chatbot.Application do
  @moduledoc """
  Supervision tree: a Registry + DynamicSupervisor for per-chat `Chatbot.Conversation`
  processes, plus the configured chat adapter (if any).
  """
  use Application

  @impl true
  def start(_type, _args) do
    adapter = List.wrap(Application.get_env(:chatbot, :adapter))

    children =
      [
        {Registry, keys: :unique, name: Chatbot.Registry},
        {DynamicSupervisor, name: Chatbot.ConversationSup, strategy: :one_for_one}
      ] ++ adapter

    Supervisor.start_link(children, strategy: :one_for_one, name: Chatbot.Supervisor)
  end
end
