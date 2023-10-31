defmodule BoilerPlateWeb.CabinetControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"

  describe "Recipient Cabinet API" do
    @tag :requestor
    test "should have no cabinet items by default", %{conn: conn, requestor_company: company} do
      nu = insert(:user)
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/cabinet")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "cannot list other company's cabinets", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user)
      nr = insert(:recipient, %{company_id: nc.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/cabinet")
      assert text_response(conn, 403) =~ "Forbidden"
    end

    @tag :requestor
    test "can list a single cabinet", %{conn: conn, requestor_company: company} do
      nu = insert(:user)
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      cab = insert(:cabinet, %{company_id: company.id, recipient_id: nr.id, status: 0})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/cabinet")
      assert length(json_response(conn, 200)) == 1

      r0 = Enum.at(json_response(conn, 200), 0)
      assert r0["id"] == cab.id
      assert r0["name"] == cab.name
    end

    @tag :requestor
    test "can list multiple cabinets", %{conn: conn, requestor_company: company} do
      nu = insert(:user)
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      insert(:cabinet, %{company_id: company.id, recipient_id: nr.id, status: 0})
      insert(:cabinet, %{company_id: company.id, recipient_id: nr.id, status: 0})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/cabinet")
      assert length(json_response(conn, 200)) == 2
    end

    @tag :requestor
    test "can upload a cabinet", %{conn: conn, requestor_company: company} do
      nu = insert(:user)
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      # figure the correct hash
      body = File.read!(@sample_iac_pdf)
      expected_hash = :crypto.hash(:sha3_256, body) |> Base.encode16() |> String.downcase()

      # Do the upload
      upload = %Plug.Upload{path: @sample_iac_pdf, filename: "bill-of-sale.pdf"}

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/cabinet", %{
          "name" => "Bill of Sale",
          "upload" => upload
        })

      assert text_response(conn, 200) =~ "OK"

      # Check that the file correctly uploaded
      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/cabinet")
      assert length(json_response(conn, 200)) == 1
      rd = Enum.at(json_response(conn, 200), 0)

      # Check dproxy API
      conn = get(conn, "/n/api/v1/dproxy/#{rd["file_name"]}")
      assert response(conn, 200)

      headers = Enum.into(conn.resp_headers, %{})
      assert Map.has_key?(headers, "content-disposition")
      assert Map.get(headers, "content-disposition") =~ "attachment"

      response_body = response(conn, 200)
      actual_hash = :crypto.hash(:sha3_256, response_body) |> Base.encode16() |> String.downcase()
      assert expected_hash == actual_hash
    end
  end
end
