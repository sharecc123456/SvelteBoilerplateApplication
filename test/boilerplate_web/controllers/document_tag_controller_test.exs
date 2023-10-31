defmodule BoilerPlateWeb.DocumentTagControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  describe "Document Tagging API" do
    @tag :requestor
    test "there are no tags by default", %{conn: conn, requestor_company: company} do
      conn = get(conn, "/n/api/v1/company/#{company.id}/tags?type=document")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "cannot access other company's tags", %{conn: conn, requestor_company: company} do
      conn = get(conn, "/n/api/v1/company/#{company.id + 1000}/tags?type=document")
      assert text_response(conn, 403) =~ "Forbidden"
    end

    @tag :requestor
    test "can create tags", %{conn: conn, requestor_company: company} do
      conn =
        post(conn, "/n/api/v1/company/#{company.id}/tags?type=document", %{
          "name" => "TESTTAG"
        })

      assert json_response(conn, 200)

      conn = get(conn, "/n/api/v1/company/#{company.id}/tags?type=document")
      assert json_response(conn, 200)
      r = json_response(conn, 200)
      assert length(r) == 1

      assert Enum.at(r, 0)["name"] == "TESTTAG"
      assert Enum.at(r, 0)["flags"] == 0
    end

    @tag :requestor
    test "can create tags with sensitivity level", %{conn: conn, requestor_company: company} do
      conn =
        post(conn, "/n/api/v1/company/#{company.id}/tags?type=document", %{
          "name" => "TESTTAG",
          "flags" => 1337
        })

      assert json_response(conn, 200)

      conn = get(conn, "/n/api/v1/company/#{company.id}/tags?type=document")
      assert json_response(conn, 200)
      r = json_response(conn, 200)
      assert length(r) == 1

      assert Enum.at(r, 0)["name"] == "TESTTAG"
      assert Enum.at(r, 0)["flags"] == 1337
    end

    @tag :requestor
    test "cannot add to  other company's tags", %{conn: conn, requestor_company: company} do
      conn =
        post(conn, "/n/api/v1/company/#{company.id + 1000}/tags?type=document", %{
          "name" => "TESTTAG"
        })

      assert text_response(conn, 403) =~ "forbidden"

      conn =
        post(conn, "/n/api/v1/company/#{company.id + 1000}/tags?type=document", %{
          "name" => "TESTTAG",
          "flags" => 1337
        })

      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "can access a tag by its id", %{conn: conn, requestor_company: company} do
      dt = insert(:document_tag, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/document-tag/#{dt.id}?type=document")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert r["id"] == dt.id
      assert r["name"] == dt.name
      assert r["color"] == dt.color
      assert r["company"] == company.id
      assert r["flags"] == 0
    end

    @tag :requestor
    test "cannot access a nonexistent tag", %{conn: conn, requestor_company: company} do
      dt = insert(:document_tag, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/document-tag/#{dt.id + 1000}?type=document")
      assert text_response(conn, 403) =~ "Forbidden"
    end
  end
end
