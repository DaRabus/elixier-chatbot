defmodule Chatbot.Tool do
  @moduledoc """
  Contract for something the AI model may do. To add a tool: implement this behaviour and
  add the module to `:tools` in config/config.exs. Nothing else to wire up.

    * `name/0`        - snake_case identifier the model calls
    * `description/0` - tells the model WHEN to use it (write this carefully)
    * `parameters/0`  - JSON schema of the arguments
    * `dangerous?/0`  - true = admin-only + needs a yes/no confirmation in chat
    * `run/2`         - receives the model's args and the triggering `Chatbot.Message`;
                        the returned string is shown to the model, not the user
  """
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()
  @callback dangerous?() :: boolean()
  @callback run(args :: map(), ctx :: Chatbot.Message.t()) :: {:ok, String.t()} | {:error, String.t()}
end
