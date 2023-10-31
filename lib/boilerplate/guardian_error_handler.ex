defmodule BoilerPlate.GuardianErrorHandler do
  import Plug.Conn
  import Phoenix.Controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, _opts) do
    cond do
      type == :unauthenticated ->
        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "stormwind.html"})
        |> put_view(BoilerPlateWeb.StormwindView)
        |> BoilerPlateWeb.StormwindController.unauthenticated(%{})

      type == :email_notverified ->
        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "app.html"})
        |> put_view(BoilerPlateWeb.ErrorView)
        |> render("not_verified.html")

      type == :terms_notaccepted ->
        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "stormwind.html"})
        |> put_view(BoilerPlateWeb.StormwindView)
        |> BoilerPlateWeb.StormwindController.terms_not_accepted(%{})

      type == :two_factor_auth_failure ->
        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "stormwind.html"})
        |> put_view(BoilerPlateWeb.StormwindView)
        |> BoilerPlateWeb.StormwindController.mfa_ask_code(%{user: reason})

      type == :not_a_requestor ->
        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "stormwind.html"})
        |> put_view(BoilerPlateWeb.StormwindView)
        |> BoilerPlateWeb.StormwindController.not_a_requestor(%{})

      type == :not_internal ->
        conn
        |> text("Internal Only")

      type == :invalid_token ->
        conn
        |> fetch_session()
        |> put_session(:recipient_company_id, nil)
        |> BoilerPlate.Guardian.Plug.sign_out()
        |> redirect(to: "/")

      True ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(401, to_string(type))
    end
  end
end
