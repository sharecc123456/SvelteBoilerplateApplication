defmodule BoilerPlateWeb.StormwindController do
  use BoilerPlateWeb, :controller

  defp html_page(_), do: "base.html"

  # Recipient Side
  defp stormwind_render(conn, page, params) do
    claims = conn |> BoilerPlate.Guardian.Plug.current_claims()

    is_impersonate? =
      if claims == nil do
        false
      else
        Map.has_key?(claims, "blptimp")
      end

    conn
    |> put_layout({BoilerPlateWeb.LayoutView, "stormwind.html"})
    |> put_view(BoilerPlateWeb.StormwindView)
    |> render(html_page(page),
      params: params,
      stormwind_role: page,
      stormwind_roleimp: is_impersonate?
    )
  end

  def recipient_side(conn, _params), do: stormwind_render(conn, :recipient, %{test_text: "Hello"})
  def login(conn, _params), do: stormwind_render(conn, :login, %{})
  def unauthenticated(conn, _params), do: stormwind_render(conn, :unauthenticated, %{})
  def terms_not_accepted(conn, _params), do: stormwind_render(conn, :terms_not_accepted, %{})
  def midlogin(conn, params), do: stormwind_render(conn, :midlogin, params)
  def recipientchoice(conn, _params), do: stormwind_render(conn, :recipient_choose, %{})
  def forgotpassword(conn, _params), do: stormwind_render(conn, :forgot_password, %{})
  def verify_signature(conn, _params), do: stormwind_render(conn, :verify_signature, %{})
  def recipient_deleted(conn, _params), do: stormwind_render(conn, :recipient_deleted, %{})
  def bad_signature(conn, _param), do: stormwind_render(conn, :bad_signature, %{})
  def bad_adhoc(conn, _param), do: stormwind_render(conn, :bad_adhoc, %{})

  def not_a_requestor(conn, _params) do
    conn
    |> put_status(403)
    |> text("Forbidden")
  end

  def mfa_ask_code(conn, %{user: us_user}) do
    type =
      if us_user.two_factor_state == 4 do
        "app"
      else
        "phone"
      end

    stormwind_render(conn, :mfa_ask_code, %{user_id: us_user.id, type: type})
  end

  def ok_signature(conn, %{
        signer_name: signer_name,
        signer_email: signer_email,
        audit_ip: audit_ip,
        inserted_at: inserted_at,
        document_title: title
      }) do
    stormwind_render(conn, :signature_ok, %{
      signer_name: signer_name,
      signer_email: signer_email,
      audit_ip: audit_ip,
      inserted_at: inserted_at,
      document_title: title
    })
  end

  def resetpassword(conn, %{email: em, lhash: lh, uid: uid}),
    do: stormwind_render(conn, :reset_password, %{email: em, uid: uid, lhash: lh})

  def adhoc_package(conn, adhoc),
    do: stormwind_render(conn, :adhoc_package, %{adhoc_string: adhoc.adhoc_string})
end
