defmodule Chatbot.Router do
  @moduledoc """
  Single entry point for incoming messages (called by chat adapters).

  Deterministic commands are handled here without the AI:

    * `/team <text>` - forward straight to the team chat
    * `/id`          - show chat id and user id (for TEAM_CHAT_ID / ADMINS / ALLOWED_USERS)
    * `/reset`       - drop this chat's AI conversation history

  Everything else goes to the chat's `Chatbot.Conversation` (AI + tools).
  """
  alias Chatbot.{Conversation, Message}

  @spec handle(Message.t()) :: :ok
  def handle(%Message{text: text} = msg) do
    if String.trim(text) != "" and allowed?(msg.user_id), do: dispatch(msg)
    :ok
  end

  defp dispatch(%{text: "/team " <> text} = msg) do
    case Chatbot.Tools.NotifyTeam.run(%{"message" => text}, msg) do
      {:ok, _} -> msg.adapter.send_message(msg.chat_id, "Forwarded to the team.")
      {:error, e} -> msg.adapter.send_message(msg.chat_id, "Could not forward: #{e}")
    end
  end

  defp dispatch(%{text: "/id"} = msg) do
    msg.adapter.send_message(msg.chat_id, "chat_id: #{msg.chat_id}\nuser_id: #{msg.user_id}")
  end

  defp dispatch(%{text: "/reset"} = msg) do
    case Registry.lookup(Chatbot.Registry, key(msg)) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Chatbot.ConversationSup, pid)
      [] -> :ok
    end

    msg.adapter.send_message(msg.chat_id, "Conversation reset.")
  end

  defp dispatch(msg) do
    pid =
      case DynamicSupervisor.start_child(Chatbot.ConversationSup, {Conversation, key(msg)}) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    Conversation.say(pid, msg)
  end

  defp key(msg), do: {msg.adapter, msg.chat_id}

  # Empty allowlist = everyone. Dangerous tools have their own stricter check (:admins).
  defp allowed?(user_id) do
    case Application.get_env(:chatbot, :allowed_users, []) do
      [] -> true
      users -> user_id in users
    end
  end
end
