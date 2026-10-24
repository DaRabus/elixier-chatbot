defmodule Chatbot.Chat.Console do
  @moduledoc """
  Stdin/stdout adapter for local development. Run with `mix run --no-halt`.
  The user id is `"console"`; add it to `ADMINS` to try the dangerous tools.
  """
  use Task, restart: :temporary
  @behaviour Chatbot.Chat.Adapter

  def start_link(_), do: Task.start_link(&loop/0)

  defp loop do
    case IO.gets("") do
      :eof ->
        :ok

      line ->
        Chatbot.Router.handle(%Chatbot.Message{
          adapter: __MODULE__,
          chat_id: "console",
          user_id: "console",
          user_name: "console",
          text: String.trim(line)
        })

        loop()
    end
  end

  @impl true
  def send_message(_chat_id, text), do: IO.puts("bot> " <> text)
end
