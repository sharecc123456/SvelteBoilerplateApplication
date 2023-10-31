alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.CompanyIntegration
alias BoilerPlate.User
alias BoilerPlate.UserSSO
alias BoilerPlate.StorageProvider
alias BoilerPlate.OAuthStrategies.GoogleOAuthStrategy
alias BoilerPlate.OAuthStrategies.BoxOauthStrategy
require Logger

defmodule BoilerPlateWeb.IntegrationController do
  use BoilerPlateWeb, :controller

  # Signing key for HMAC-SHA256 used to ensure that OAuth2 state variable is not
  # mangled with and is protected against CSRF.
  @oauth_state_signing_key "SXgcp8FaCdA/VP+8W4amO2rKSELQh0TG+Bi2RtDzwVBK9MKYQPhr3BeXkHWH8p68"

  # Set to one hour, it's the grace period for the maximum time an OAuth2
  # authentication/authorization can take. Lower is more secure, but I (Lev)
  # think this should be fine.
  @oauth_grace_period 60 * 60 * 1

  # Sign the state with HMAC-SHA256 so that we can be sure that we sent this
  # state to the OAuth2 Provider.
  defp sign_state(state) do
    current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

    sig =
      :crypto.mac(:hmac, :sha256, @oauth_state_signing_key, Poison.encode!(state))
      |> Base.encode16()

    state
    |> Map.put(:sig, sig)
    |> Map.put(:iat, current_timestamp)
  end

  @doc """
  List the contacts the user has in their integrated Google Contacts. The
  payload is a list encoded as JSON.

  See `APIs.GoogleContacts.list_contacts/1` for the actual format.

  If there is no integrations, it returns HTTP 404 Not Found, with a payload of
  an empty array encoded as JSON.
  """
  def google_contacts_list(conn, _params) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> json([])
    else
      company = Repo.get(Company, requestor.company_id)
      integration = CompanyIntegration.of(company, "contacts_google")

      if integration == nil do
        Logger.error("null integration!")
        conn |> put_status(404) |> json([])
      else
        case APIs.GoogleContacts.get_client(integration) do
          {:ok, client} ->
            client = APIs.GoogleContacts.new(client.token.access_token)
            x = APIs.GoogleContacts.list_contacts(client)
            conn |> json(x)

          r ->
            Logger.warning(message: "google_contacts/list/get_client", ret: r)
            conn |> put_status(400) |> json([])
        end
      end
    end
  end

  @doc """
  Connects an SSO using a JWT credential supplied by the SSO button to a user.

  Returns (code/error_code):
    - 200/ok: All is OK, the user is connected
    - 400/sso_bad_requestor: Not a requestor
    - 400/sso_invalid: Email is not verified (as reported by the JWT)
    - 400/sso_already: This SSO account is already attached to another BLPT account.
    - 400/sso_no_user: Couldn't find a suitable user for this request.
    - 400/sso_bad_token: JWT couldn't be verified
  """
  def add_sso(conn, %{"type" => "google", "credential" => jwt}) do
    with {:ok, claims} <- Crypto.GoogleJWTManager.verify_and_validate(jwt) do
      email_verified = claims["email_verified"]
      requestor = get_current_requestor(conn)

      cond do
        requestor == nil ->
          conn |> put_status(400) |> json(%{error: :sso_bad_requestor})

        not email_verified ->
          conn |> put_status(400) |> json(%{error: :sso_invalid})

        true ->
          case UserSSO.connect_to(Repo.get(User, requestor.user_id), "google", %{
                 sub: claims["sub"]
               }) do
            {:ok, _user} ->
              conn |> json(%{status: :ok})

            {:err, :other_account} ->
              conn |> put_status(400) |> json(%{error: :sso_already})

            {:err, :no_user} ->
              conn |> put_status(400) |> json(%{error: :sso_no_user})
          end
      end
    else
      _ ->
        conn |> put_status(400) |> json(%{error: :sso_bad_token})
    end
  end

  #########################
  ## (De-)Authorization  ##
  #########################

  @doc """
  Authorize an integration. The param `integration_type` will route the request
  properly and redirect the user to an OAuth2 login URL using the integration's
  OAuthStrategy. A state variable is then included, that is signed with an
  HMAC-SHA256 algorithm to ensure that we are not vulnerable to CSRF or other
  types of attacks.
  """
  def authorize_integration(conn, params = %{"integration_type" => it}) do
    case it do
      "google" -> authorize_google(conn, params)
      "box" -> authorize_box(conn, params)
      "google_contacts" -> authorize_google_contacts(conn, params)
      _ -> text(conn, "Bad integration type")
    end
  end

  defp authorize_google(conn, _params) do
    requestor = get_current_requestor(conn)

    state = %{
      typ: :google,
      rqi: requestor.id
    }

    redirect(conn,
      external:
        GoogleOAuthStrategy.authorize_url!(
          "https://www.googleapis.com/auth/drive.file",
          sign_state(state)
        )
    )
  end

  defp authorize_box(conn, _params) do
    requestor = get_current_requestor(conn)

    state = %{
      typ: :box,
      rqi: requestor.id
    }

    redirect(conn,
      external:
        BoxOauthStrategy.authorize_url!(
          "",
          sign_state(state)
        )
    )
  end

  defp authorize_google_contacts(conn, _params) do
    requestor = get_current_requestor(conn)

    state = %{
      typ: :google_contacts,
      rqi: requestor.id
    }

    redirect(conn,
      external:
        GoogleOAuthStrategy.authorize_url!(
          "https://www.googleapis.com/auth/contacts.readonly",
          sign_state(state)
        )
    )
  end

  @doc """
  Called when the user wants to deauthorize an integration. Based on the
  `integration_type` argument's value, it routes to the correct integration
  submodule (UserSSO, StorageProvider or CompanyIntegration).

  TODO: Ensure that the integration is actually told that we are deregistering?
  """
  def deauthorize_integration(conn, %{"integration_type" => integration_type}) do
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> json(%{error: :forbidden})

      StorageProvider.type_valid?(integration_type) ->
        case StorageProvider.deauthorize(
               Repo.get(Company, requestor.company_id),
               integration_type
             ) do
          :ok -> text(conn, "OK")
          {:error, e} -> conn |> put_status(400) |> json(%{error: e})
        end

      CompanyIntegration.type_valid?(integration_type) ->
        case CompanyIntegration.deauthorize(
               Repo.get(Company, requestor.company_id),
               integration_type
             ) do
          :ok -> text(conn, "OK")
          {:error, e} -> conn |> put_status(400) |> json(%{error: e})
        end

      UserSSO.type_valid?(integration_type) ->
        case UserSSO.deauthorize(Repo.get(User, requestor.user_id), integration_type) do
          :ok -> text(conn, "OK")
          {:error, e} -> conn |> put_status(400) |> json(%{error: e})
        end

      true ->
        conn |> put_status(400) |> json(%{error: :invalid_integration})
    end
  end

  ##############################
  ## OAuth2 Callback Handlers ##
  ##############################

  # Called when the Box integration returns with a grant from Box.
  defp do_oauth_callback_box(conn, oauth_code, state) do
    requestor = get_current_requestor(conn)
    rqi = state["rqi"]
    Logger.metadata()
    Logger.info("do_oauth_callback_box")

    if rqi == requestor.id do
      case BoxOauthStrategy.get_token!(code: oauth_code)
           |> BoxOauthStrategy.save_to_company(
             {:storage_provider, :permanent},
             Repo.get(Company, requestor.company_id)
           ) do
        {:error, t} -> text(conn, "oauthcallback error: #{t}")
        _ -> redirect(conn, to: "/n/requestor#admin?integrations=true&type=box&success=true")
      end
    else
      text(conn, "invalid state")
    end
  end

  # Called when the Google Drive integration returns with a grant
  # from Google.
  defp do_oauth_callback_google(conn, oauth_code, state) do
    requestor = get_current_requestor(conn)
    rqi = state["rqi"]
    Logger.info("do_oauth_callback_google")

    if rqi == requestor.id do
      case GoogleOAuthStrategy.get_token!(code: oauth_code)
           |> GoogleOAuthStrategy.save_to_company(
             {:storage_provider, :permanent},
             Repo.get(Company, requestor.company_id)
           ) do
        {:error, t} -> text(conn, "oauthcallback error: #{t}")
        _ -> redirect(conn, to: "/n/requestor#admin?integrations=true&type=google&success=true")
      end
    else
      text(conn, "invalid state")
    end
  end

  # Called when the google contacts integration returns with a grant
  # from Google.
  defp do_oauth_callback_google_contacts(conn, oauth_code, state) do
    requestor = get_current_requestor(conn)
    rqi = state["rqi"]
    Logger.info("do_oauth_callback_google_contacts")

    if rqi == requestor.id do
      GoogleOAuthStrategy.get_token!(code: oauth_code)
      |> GoogleOAuthStrategy.save_to_company(
        {:integration, "contacts_google"},
        Repo.get(Company, requestor.company_id)
      )

      redirect(conn, to: "/n/requestor#admin?integrations=true&type=google&success=true")
    else
      text(conn, "invalid state")
    end
  end

  @doc """
  The main routing point for OAuth2 Callbacks. Grabs the `code`, and the `state`
  that (hopefully) we generated. It then proceeds to verify the authenticity of
  the State and if it works then passes it to individual oauth2 callback
  handlers. This part of the routing is done via the state's `typ` field, so it
  is IMPERATIVE that the HMAC verification works.

  Returns:
    - "Invalid attempt" if the `typ` is unrecognized.
    - "Your attempt is invalid or has expired" if the state's signature cannot
      be verified or its grace period has passed. See @oauth_grace_period.
  """
  def oauth_callback(conn, _params = %{"code" => oauth_code, "state" => raw_state}) do
    # Grab the state and verify that it is correctly signed
    state = Poison.decode!(raw_state)
    sig = state["sig"]
    ts = state["iat"]
    current_timestamp = DateTime.utc_now() |> DateTime.to_unix()
    Logger.info("oauth_callback(code: #{oauth_code})")

    actual_sig =
      :crypto.mac(
        :hmac,
        :sha256,
        @oauth_state_signing_key,
        state |> Map.drop(["sig", "iat"]) |> Poison.encode!()
      )
      |> Base.encode16()

    if actual_sig == sig and current_timestamp - ts < @oauth_grace_period do
      case state["typ"] do
        "google" -> do_oauth_callback_google(conn, oauth_code, state)
        "box" -> do_oauth_callback_box(conn, oauth_code, state)
        "google_contacts" -> do_oauth_callback_google_contacts(conn, oauth_code, state)
        _ -> text(conn, "Invalid attempt")
      end
    else
      Logger.warning("Expected HMAC: #{actual_sig}, Actual HMAC: #{sig}")
      Logger.debug(state, label: "oauth_callback state")
      text(conn, "Your attempt is invalid or has expired - please try again.")
    end
  end
end
