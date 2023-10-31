defmodule Crypto.GoogleJWTManager do
  @moduledoc false

  use Joken.Config, default_signer: nil

  @iss "https://accounts.google.com"

  # your google client id (usually ends in *.apps.googleusercontent.com)
  defp aud, do: "742228283026-dho0g52hf3727v014v9ahanbmevqhkbn.apps.googleusercontent.com"

  # reference your custom verify hook here
  add_hook(Crypto.GoogleVerifyHook)

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("iss", nil, &(&1 == @iss))
    |> add_claim("aud", nil, &(&1 == aud()))
  end
end
