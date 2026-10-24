defmodule Chatbot.Chat.Adapter do
  @moduledoc """
  Contract for a chat platform (MS Teams, Slack, Matrix, ...).

  An adapter is a supervised process that receives messages from the platform and calls
  `Chatbot.Router.handle/1` with a `Chatbot.Message`. It must also implement `send_message/2`
  so the bot can answer. Register it via the `:adapter` config key (see config/runtime.exs).
  """
  @callback send_message(chat_id :: String.t(), text :: String.t()) :: :ok | {:error, term()}
end
