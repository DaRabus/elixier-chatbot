defmodule Chatbot.Tools.VmCommand do
  @moduledoc """
  Runs a NAMED command (see `:vm_commands`) on an allowlisted host (`VM_HOSTS`) over ssh.
  The model can never supply raw shell. Needs key-based ssh for the user running the bot.
  """
  @behaviour Chatbot.Tool

  @impl true
  def name, do: "vm_command"

  @impl true
  def description, do: "Run a predefined command (e.g. restart, status) on one of our VMs via ssh."

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{
        host: %{type: "string", enum: hosts()},
        command: %{type: "string", enum: Map.keys(commands())}
      },
      required: ["host", "command"]
    }
  end

  @impl true
  def dangerous?, do: true

  @impl true
  def run(%{"host" => host, "command" => command}, _ctx) do
    cond do
      host not in hosts() -> {:error, "host not allowed"}
      not is_map_key(commands(), command) -> {:error, "unknown command"}
      true -> Chatbot.Shell.run("ssh", ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, commands()[command]])
    end
  end

  def run(_, _), do: {:error, "missing arguments: host, command"}

  defp hosts, do: Application.get_env(:chatbot, :vm_hosts, [])
  defp commands, do: Application.get_env(:chatbot, :vm_commands, %{})
end
