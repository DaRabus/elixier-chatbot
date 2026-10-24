defmodule Chatbot.ToolsTest do
  use ExUnit.Case

  alias Chatbot.Tools.{CreateVm, VmCommand}

  setup do
    Application.put_env(:chatbot, :vm_hosts, ["ops@vm1"])
    on_exit(fn -> Application.put_env(:chatbot, :vm_hosts, []) end)
  end

  test "vm_command rejects hosts and commands outside the allowlist" do
    assert {:error, _} = VmCommand.run(%{"host" => "evil@x", "command" => "restart"}, %{})
    assert {:error, _} = VmCommand.run(%{"host" => "ops@vm1", "command" => "rm -rf /"}, %{})
  end

  test "create_vm rejects unsafe names" do
    assert {:error, "invalid VM name"} = CreateVm.run(%{"name" => "a; rm -rf /"}, %{user_id: "1"})
  end

  test "every configured tool produces an Ollama spec" do
    assert length(Chatbot.Tools.specs()) == length(Chatbot.Tools.all())
  end
end
