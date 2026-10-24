defmodule Chatbot.Tools.CreateVm do
  @moduledoc """
  Creates a VM by calling `CREATE_VM_SCRIPT <name> <requesting_user_id>`.
  The script owns the real backend (virsh, Proxmox API, Terraform, ...), so swapping
  hypervisors never touches Elixir code. Its stdout is returned to the model.
  """
  @behaviour Chatbot.Tool

  @impl true
  def name, do: "create_vm"

  @impl true
  def description, do: "Create a new virtual machine for the user."

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{name: %{type: "string", description: "lowercase letters, digits, dashes; 3-32 chars"}},
      required: ["name"]
    }
  end

  @impl true
  def dangerous?, do: true

  @impl true
  def run(%{"name" => name}, ctx) do
    script = Application.get_env(:chatbot, :create_vm_script)

    cond do
      not Regex.match?(~r/\A[a-z0-9-]{3,32}\z/, name) -> {:error, "invalid VM name"}
      is_nil(script) -> {:error, "CREATE_VM_SCRIPT is not configured"}
      true -> Chatbot.Shell.run(script, [name, ctx.user_id], 300_000)
    end
  end

  def run(_, _), do: {:error, "missing argument: name"}
end
