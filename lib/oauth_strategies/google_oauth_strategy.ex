alias BoilerPlate.Company
alias BoilerPlate.StorageProvider
alias BoilerPlate.CompanyIntegration
require Logger

defmodule BoilerPlate.OAuthStrategies.GoogleOAuthStrategy do
  use OAuth2.Strategy

  @google_client_id "742228283026-dho0g52hf3727v014v9ahanbmevqhkbn.apps.googleusercontent.com"
  @google_client_secret "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"

  def new do
    dmn = "#{Application.get_env(:boilerplate, :boilerplate_domain)}/_oauth/callback"

    OAuth2.Client.new(
      strategy: __MODULE__,
      client_id: @google_client_id,
      client_secret: @google_client_secret,
      redirect_uri: dmn,
      site: "https://www.googleapis.com/upload/drive",
      authorize_url: "https://accounts.google.com/o/oauth2/auth",
      token_url: "https://oauth2.googleapis.com/token"
    )
    |> OAuth2.Client.put_serializer("application/json", Jason)
  end

  def get_access_token(refresh_token) do
    refresh_client =
      OAuth2.Client.new(
        strategy: OAuth2.Strategy.Refresh,
        client_id: @google_client_id,
        client_secret: @google_client_secret,
        site: "https://oauth2.googleapis.com/token",
        token_url: "https://oauth2.googleapis.com/token",
        params: %{"refresh_token" => refresh_token}
      )
      |> OAuth2.Client.put_serializer("application/json", Jason)

    case OAuth2.Client.get_token(refresh_client) do
      {:ok, client} ->
        new_refresh_token = client.token.refresh_token

        # A refresh token is not always provided - if it's not, it means that it
        # has not yet expired and will last at least as long as the access
        # token. So we compare, and tell upstream whether the StorageProvider
        # has to be updated.
        if new_refresh_token != nil and new_refresh_token != refresh_token do
          {:new_refresh_token, new_refresh_token, client}
        else
          {:ok, client}
        end

      {:error, x} ->
        {:error, x}
    end
  end

  def authorize_url!(scope, state, params \\ []) do
    new()
    |> put_param(
      :scope,
      scope
    )
    |> put_param(
      :access_type,
      "offline"
    )
    |> put_param(
      :state,
      Poison.encode!(state)
    )
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_token!(params \\ [], headers \\ []) do
    OAuth2.Client.get_token!(new(), params, headers)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  # Integrations

  def save_to_company(
        %OAuth2.Client{token: token},
        xp,
        %Company{} = company
      ),
      do: save_to_company(token, xp, company)

  def save_to_company(
        %OAuth2.AccessToken{refresh_token: nil} = client,
        _xp,
        %Company{} = _company
      ) do
    Logger.info("save_to_company/no_refresh_token")
    IO.inspect(client, label: "save_to_company/no_refresh_token")
    {:error, "no refresh token?"}
  end

  def save_to_company(
        %OAuth2.AccessToken{refresh_token: refresh_token} = _client,
        {:integration, integration_type},
        %Company{} = company
      ) do
    Logger.info("save_to_company/integration/#{integration_type}")

    if CompanyIntegration.has_integration?(company, integration_type) do
      CompanyIntegration.update_integration(company, integration_type, %{
        refresh_token: refresh_token
      })

      Logger.info("save_to_company/integration/#{integration_type}/update")
    else
      CompanyIntegration.create(%{
        data: %{
          refresh_token: refresh_token
        },
        company_id: company.id,
        type: integration_type,
        status: 0,
        flags: 0
      })
      |> CompanyIntegration.set_for(company, integration_type)

      Logger.info("save_to_company/integration/#{integration_type}/create")
    end
  end

  def save_to_company(
        %OAuth2.AccessToken{refresh_token: refresh_token} = _client,
        {:storage_provider, :permanent},
        %Company{} = company
      ) do
    # Check if there is a storage provider already for this company
    if StorageProvider.has_permanent?(company) do
      StorageProvider.update_metadata(company, :permanent, "gdrive", %{
        refresh_token: refresh_token
      })
    else
      StorageProvider.create(%{
        backend: "gdrive",
        meta_data: %{
          refresh_token: refresh_token
        },
        status: 0,
        flags: 0
      })
      |> StorageProvider.set_for(company, :permanent)
    end
  end
end
