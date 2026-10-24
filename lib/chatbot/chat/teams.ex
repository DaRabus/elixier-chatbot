defmodule Chatbot.Chat.Teams do
  @moduledoc """
  Microsoft Teams adapter (Azure Bot Service / Bot Framework).

  Flow:
    * Teams -> Azure Bot -> `POST /api/messages` on this app (`Chatbot.Chat.Teams.Plug`),
      authenticated by a JWT from Microsoft (`Chatbot.Chat.Teams.Auth`).
    * Bot -> Teams: `POST <serviceUrl>/v3/conversations/<id>/activities` with an OAuth token
      obtained via client credentials.

  In channels and group chats Teams only delivers messages that @mention the bot, so no
  command prefix is needed. Needs a public HTTPS endpoint (reverse proxy or dev tunnel).

  The service URL of each conversation is remembered in memory (learned from incoming messages);
  `TEAMS_SERVICE_URL` is the fallback, e.g. for proactive posts to `TEAM_CHAT_ID` after a restart.
  """
  use Supervisor
  @behaviour Chatbot.Chat.Adapter

  alias Chatbot.Chat.Teams.State

  def start_link(_), do: Supervisor.start_link(__MODULE__, nil)

  @impl Supervisor
  def init(_) do
    port = Application.fetch_env!(:chatbot, :port)
    Supervisor.init([State, {Bandit, plug: Chatbot.Chat.Teams.Plug, port: port}], strategy: :one_for_one)
  end

  @impl Chatbot.Chat.Adapter
  def send_message(chat_id, text) do
    base = State.get({:service_url, chat_id}) || Application.get_env(:chatbot, :teams_service_url)

    with base when is_binary(base) <- base || {:error, :unknown_service_url},
         {:ok, token} <- token(),
         url = String.trim_trailing(base, "/") <> "/v3/conversations/#{chat_id}/activities",
         {:ok, %{status: status}} when status in 200..299 <-
           Req.post(url, json: %{type: "message", text: text}, auth: {:bearer, token}) do
      :ok
    else
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, _} = err -> err
    end
  end

  defp token do
    now = System.os_time(:second)

    case State.get(:token) do
      {token, expires} when expires > now ->
        {:ok, token}

      _ ->
        tenant = Application.fetch_env!(:chatbot, :teams_tenant_id)

        form = [
          grant_type: "client_credentials",
          client_id: Application.fetch_env!(:chatbot, :teams_app_id),
          client_secret: Application.fetch_env!(:chatbot, :teams_app_secret),
          scope: "https://api.botframework.com/.default"
        ]

        case Req.post("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token", form: form) do
          {:ok, %{status: 200, body: %{"access_token" => t, "expires_in" => secs}}} ->
            State.put(:token, {t, now + secs - 60})
            {:ok, t}

          other ->
            {:error, {:token, other}}
        end
    end
  end
end
