defmodule Chatbot.Chat.Teams.Auth do
  @moduledoc """
  Validates the `Authorization: Bearer <jwt>` header Microsoft sends with each activity:
  RS256 signature against Microsoft's published keys, issuer, audience (our app id) and expiry.
  Without this anyone could POST fake messages (and thereby trigger tools).
  """
  alias Chatbot.Chat.Teams.State

  @openid "https://login.botframework.com/v1/.well-known/openidconfiguration"
  @issuer "https://api.botframework.com"

  @spec verify(String.t()) :: {:ok, map()} | :error
  def verify("Bearer " <> token) do
    %{"kid" => kid} = token |> JOSE.JWS.peek_protected() |> Jason.decode!()

    with {:ok, jwk} <- key(kid),
         {true, %{fields: claims}, _} <- JOSE.JWT.verify_strict(jwk, ["RS256"], token),
         true <- valid?(claims) do
      {:ok, claims}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  def verify(_), do: :error

  defp valid?(claims) do
    exp = claims["exp"]

    claims["iss"] == @issuer and claims["aud"] == Application.fetch_env!(:chatbot, :teams_app_id) and
      is_integer(exp) and exp > System.os_time(:second)
  end

  # Keys are cached for 24h. An unknown kid may mean Microsoft rotated keys: refetch, but at most every 5 min.
  defp key(kid) do
    {keys, fetched_at} = State.get(:jwks) || {[], 0}
    age = System.os_time(:second) - fetched_at
    known? = Enum.any?(keys, &(&1["kid"] == kid))
    keys = if age > 86_400 or (not known? and age > 300), do: fetch_keys(keys), else: keys

    case Enum.find(keys, &(&1["kid"] == kid)) do
      nil -> :error
      map -> {:ok, JOSE.JWK.from_map(map)}
    end
  end

  defp fetch_keys(old) do
    with {:ok, %{body: %{"jwks_uri" => uri}}} <- Req.get(@openid),
         {:ok, %{body: %{"keys" => keys}}} <- Req.get(uri) do
      State.put(:jwks, {keys, System.os_time(:second)})
      keys
    else
      _ -> old
    end
  end
end
