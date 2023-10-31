defmodule BoilerPlateWeb.PageControllerTest do
  use BoilerPlateWeb.ConnCase

  test "/internal/version should show a version", %{conn: conn} do
    conn = get(conn, "/internal/version")

    assert text_response(conn, 200) =~ "app: boilerplate-"
  end

  test "Terms page works", %{conn: conn} do
    conn = get(conn, "/terms")

    assert html_response(conn, 200) =~ "TERMS OF SERVICE"
  end
end
