defmodule Chatbot.Message do
  @moduledoc """
  Platform-neutral incoming message. Adapters build this and hand it to `Chatbot.Router.handle/1`.
  Ids are always strings. `adapter` is the module used to answer.
  """
  @enforce_keys [:adapter, :chat_id, :user_id, :text]
  defstruct [:adapter, :chat_id, :user_id, :user_name, :text]

  @type t :: %__MODULE__{
          adapter: module(),
          chat_id: String.t(),
          user_id: String.t(),
          user_name: String.t() | nil,
          text: String.t()
        }
end
