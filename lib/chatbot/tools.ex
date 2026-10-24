defmodule Chatbot.Tools do
  @moduledoc "Registry of enabled tools (the `:tools` config list)."

  def all, do: Application.get_env(:chatbot, :tools, [])
  def fetch(name), do: Enum.find(all(), &(&1.name() == name))

  @doc "Tool definitions in the format Ollama expects."
  def specs do
    for m <- all() do
      %{type: "function", function: %{name: m.name(), description: m.description(), parameters: m.parameters()}}
    end
  end
end
