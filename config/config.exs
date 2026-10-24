import Config

# Static defaults. Environment-specific values live in runtime.exs.
config :chatbot,
  adapter: nil,
  ollama_url: "http://localhost:11434",
  ollama_model: "llama3.1",
  team_chat_id: nil,
  port: 3978,
  teams_app_id: nil,
  teams_app_secret: nil,
  teams_tenant_id: nil,
  teams_service_url: nil,
  admins: [],
  allowed_users: [],
  vm_hosts: [],
  create_vm_script: nil,
  # Named commands the model may run on a VM. The model picks a NAME, never raw shell.
  vm_commands: %{
    "restart" => "sudo systemctl reboot",
    "status" => "uptime && df -h /"
  },
  # Add a tool = write a module (see Chatbot.Tool) and list it here.
  tools: [Chatbot.Tools.NotifyTeam, Chatbot.Tools.VmCommand, Chatbot.Tools.CreateVm],
  system_prompt: """
  You are the internal assistant of our team. Answer briefly.
  If a request needs a human (access, purchases, anything you cannot do), use notify_team.
  Use the VM tools only when the user clearly asks for them.
  """
