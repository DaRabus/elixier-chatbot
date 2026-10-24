defmodule Chatbot.Tools.NotifyTeam do
  @moduledoc "Forwards a message to the team chat (`TEAM_CHAT_ID`) so a human can react."
  @behaviour Chatbot.Tool

  @impl true
  def name, do: "notify_team"

  @impl true
  def description,
    do: "Send a message to the human team channel when the user needs help from a person or something must be escalated."

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{message: %{type: "string", description: "Self-contained summary for the team"}},
      required: ["message"]
    }
  end

  @impl true
  def dangerous?, do: false

  @impl true
  def run(%{"message" => text}, ctx) do
    case Application.get_env(:chatbot, :team_chat_id) do
      nil ->
        {:error, "TEAM_CHAT_ID is not configured"}

      team_chat ->
        ctx.adapter.send_message(team_chat, "From #{ctx.user_name} (id #{ctx.user_id}):\n#{text}")
        {:ok, "Team notified."}
    end
  end

  def run(_, _), do: {:error, "missing argument: message"}
end
