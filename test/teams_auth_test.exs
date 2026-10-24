defmodule Chatbot.Chat.Teams.AuthTest do
  use ExUnit.Case

  alias Chatbot.Chat.Teams.{Auth, State}

  setup do
    start_supervised!(State)
    jwk = JOSE.JWK.generate_key({:rsa, 2048})
    {_, pub} = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    State.put(:jwks, {[Map.put(pub, "kid", "k1")], System.os_time(:second)})
    Application.put_env(:chatbot, :teams_app_id, "app")
    %{jwk: jwk}
  end

  defp token(jwk, overrides \\ %{}) do
    claims = Map.merge(%{"iss" => "https://api.botframework.com", "aud" => "app", "exp" => System.os_time(:second) + 300}, overrides)
    {_, t} = jwk |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "k1"}, claims) |> JOSE.JWS.compact()
    "Bearer " <> t
  end

  test "accepts a valid token", %{jwk: jwk} do
    assert {:ok, _} = Auth.verify(token(jwk))
  end

  test "rejects wrong audience, issuer, expiry, foreign signature and garbage", %{jwk: jwk} do
    assert :error = Auth.verify(token(jwk, %{"aud" => "other"}))
    assert :error = Auth.verify(token(jwk, %{"iss" => "https://evil.example"}))
    assert :error = Auth.verify(token(jwk, %{"exp" => System.os_time(:second) - 10}))
    assert :error = Auth.verify(token(JOSE.JWK.generate_key({:rsa, 2048})))
    assert :error = Auth.verify("Bearer garbage")
    assert :error = Auth.verify("nope")
  end
end
