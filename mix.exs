defmodule Chatbot.MixProject do
  use Mix.Project

  def project do
    [
      app: :chatbot,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Chatbot.Application, []}]
  end

  # req: HTTP client (Ollama, Bot Framework). plug + bandit: webhook server for Teams.
  # jose: validates the JWT Microsoft sends with every incoming activity.
  defp deps do
    [{:req, "~> 0.5"}, {:plug, "~> 1.16"}, {:bandit, "~> 1.5"}, {:jose, "~> 1.11"}, {:jason, "~> 1.4"}]
  end
end
