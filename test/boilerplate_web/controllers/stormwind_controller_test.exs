defmodule BoilerPlateWeb.StormwindControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  describe "Shared Pages" do
    test "blank request redirects to login", %{conn: conn} do
      conn = get(conn, "/")
      assert redirected_to(conn, 302) =~ "/login"
    end

    test "login page has correct role", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "data-role=\"login\""
    end

    @tag :recipient
    test "recipient page has correct role", %{conn: conn} do
      conn = get(conn, "/n/recipient")
      assert html_response(conn, 200) =~ "data-role=\"recipient\""
    end

    @tag :requestor
    test "requestor page has correct role", %{conn: conn} do
      conn = get(conn, "/n/requestor")
      assert html_response(conn, 200) =~ "data-role=\"requestor\""
    end

    @tag :recipient
    test "user with multiple companies as recipient has correct role", %{
      conn: conn,
      recipient_user: u
    } do
      nc = insert(:company)
      insert(:recipient, %{user_id: u.id, company_id: nc.id})

      conn = get(conn, "/n/recipientc")
      assert html_response(conn, 200) =~ "data-role=\"recipient_choose\""
    end
  end
end
