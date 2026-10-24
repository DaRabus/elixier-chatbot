import Config

if config_env() != :test do
  list = fn key -> System.get_env(key, "") |> String.split(",", trim: true) |> Enum.map(&String.trim/1) end

  adapter =
    case System.get_env("CHAT_ADAPTER", "console") do
      "teams" ->
        for k <- ~w(TEAMS_APP_ID TEAMS_APP_SECRET TEAMS_TENANT_ID) do
          System.get_env(k) || raise "#{k} is required for CHAT_ADAPTER=teams"
        end

        Chatbot.Chat.Teams

      _ ->
        Chatbot.Chat.Console
    end

  config :chatbot,
    adapter: adapter,
    ollama_url: System.get_env("OLLAMA_URL", "http://localhost:11434"),
    ollama_model: System.get_env("OLLAMA_MODEL", "llama3.1"),
    port: String.to_integer(System.get_env("PORT", "3978")),
    teams_app_id: System.get_env("TEAMS_APP_ID"),
    teams_app_secret: System.get_env("TEAMS_APP_SECRET"),
    teams_tenant_id: System.get_env("TEAMS_TENANT_ID"),
    teams_service_url: System.get_env("TEAMS_SERVICE_URL"),
    team_chat_id: System.get_env("TEAM_CHAT_ID"),
    admins: list.("ADMINS"),
    allowed_users: list.("ALLOWED_USERS"),
    vm_hosts: list.("VM_HOSTS"),
    create_vm_script: System.get_env("CREATE_VM_SCRIPT")
end
