defmodule Chatbot.Chat.Teams.Plug do
  @moduledoc "Webhook endpoint `POST /api/messages` that the Azure Bot resource calls."
  use Plug.Router

  alias Chatbot.Chat.Teams
  alias Chatbot.Chat.Teams.{Auth, State}

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/api/messages" do
    activity = conn.body_params

    with [header] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Auth.verify(header),
         true <- claims["serviceurl"] in [nil, activity["serviceUrl"]] do
      handle(activity)
      send_resp(conn, 200, "")
    else
      _ -> send_resp(conn, 401, "unauthorized")
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  # Answer 200 right away; the AI work happens asynchronously in the chat's Conversation process.
  defp handle(%{"type" => "message", "text" => text, "conversation" => %{"id" => chat_id}, "from" => from} = activity) do
    State.put({:service_url, chat_id}, activity["serviceUrl"])

    Chatbot.Router.handle(%Chatbot.Message{
      adapter: Teams,
      chat_id: chat_id,
      user_id: from["aadObjectId"] || from["id"],
      user_name: from["name"],
      text: text |> String.replace(~r/<at>.*?<\/at>/, "") |> String.trim()
    })
  end

  defp handle(_other), do: :ignore
end
