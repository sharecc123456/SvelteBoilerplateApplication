alias BoilerPlate.Repo
alias BoilerPlate.CompanyIntegration
require Logger

defmodule APIs.GoogleContacts do
  def new(access_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://people.googleapis.com"},
      {Tesla.Middleware.BearerAuth, token: access_token},
      Tesla.Middleware.JSON
    ])
  end

  defp process_contacts(body) do
    if body == %{} do
      []
    else
      body["connections"]
      |> Enum.map(fn x ->
        name = Enum.at(x["names"], 0)["displayName"]
        email = Enum.at(x["emailAddresses"], 0)["value"]
        organization = Enum.at(x["organizations"], 0)["name"]
        id = x["resourceName"]
        %{id: id, name: name, email: email, organization: organization}
      end)
    end
  end

  def list_contacts(client) do
    case Tesla.get(
           client,
           "/v1/people/me/connections?personFields=names,emailAddresses,organizations"
         ) do
      {:ok, resp} ->
        Logger.debug(%{message: "list_contacts/google_contacts", resp: resp})

        case resp.status do
          200 ->
            resp.body |> process_contacts()

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end

  defp store_refresh_token(sp, rf) do
    Repo.update!(
      CompanyIntegration.changeset(sp, %{
        data: %{refresh_token: rf}
      })
    )
  end

  def get_client(sp) do
    rf = sp.data["refresh_token"]

    case BoilerPlate.OAuthStrategies.GoogleOAuthStrategy.get_access_token(rf) do
      {:ok, client} ->
        {:ok, client}

      {:new_refresh_token, rf, client} ->
        store_refresh_token(sp, rf)
        {:ok, client}

      {:error, err} ->
        {:error, err}
    end
  end
end
