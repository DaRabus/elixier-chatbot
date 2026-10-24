defmodule Chatbot.Ollama do
  @moduledoc "Minimal client for Ollama's `/api/chat` (non-streaming, with tool calling)."

  @spec chat([map()], [map()]) :: {:ok, map()} | {:error, term()}
  def chat(messages, tools) do
    url = Application.fetch_env!(:chatbot, :ollama_url) <> "/api/chat"

    body = %{
      model: Application.fetch_env!(:chatbot, :ollama_model),
      messages: messages,
      tools: tools,
      stream: false
    }

    case Req.post(url, json: body, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: %{"message" => message}}} -> {:ok, message}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, e} -> {:error, e}
    end
  end
end
