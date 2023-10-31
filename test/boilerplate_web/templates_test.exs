defmodule BoilerPlateWeb.TemplatesTest do
  alias BoilerPlate.RawDocument
  alias BoilerPlate.Repo
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"

  describe "Requestor: Templates API" do
    @tag :requestor
    test "empty templates by default", %{conn: conn} do
      conn = get(conn, "/n/api/v1/templates")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "templates should return a template", %{conn: conn, requestor_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/templates")
      assert length(json_response(conn, 200)) == 1

      r = json_response(conn, 200)
      r0 = Enum.at(r, 0)

      assert r0["name"] == rd.name
      assert r0["id"] == rd.id
      assert r0["description"] == rd.description
      assert r0["file_name"] == rd.file_name

      assert r0["tags"] == %{
               "id" => [],
               "values" => []
             }
    end

    @tag :requestor
    test "can request a template by id", %{conn: conn, requestor_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)

      r0 = json_response(conn, 200)
      assert r0["name"] == rd.name
      assert r0["id"] == rd.id
      assert r0["description"] == rd.description
      assert r0["file_name"] == rd.file_name

      assert r0["tags"] == %{
               "id" => [],
               "values" => []
             }
    end

    @tag :requestor
    test "can delete a template", %{conn: conn, requestor_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})

      # check that it's there
      conn = get(conn, "/n/api/v1/templates")
      assert length(json_response(conn, 200)) == 1

      # delete it
      conn = delete(conn, "/n/api/v1/template/#{rd.id}")
      assert text_response(conn, 200) =~ "OK"

      # check that it's gone
      conn = get(conn, "/n/api/v1/templates")
      assert Enum.empty?(json_response(conn, 200))
    end

    @tag :requestor
    test "get prefilled iac template", %{conn: conn, requestor_user: us_user, requestor_company: company} do
      # recipient
      nu = insert(:user, %{company_id: company.id})
      recipient = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {iac_doc, _, rdc, assignment, _} = insert_iac_fill(us_user, company, recipient)
      conn = get(conn, "/n/api/v1/requestor/customized/doc/#{rdc.id}?assignmentId=#{assignment.id}")
      assert json_response(conn, 200)

      resp = json_response(conn, 200)
      assert resp["iac_doc_id"] == iac_doc.id
    end

    @tag :requestor
    test "show iac template", %{conn: conn, requestor_user: us_user, requestor_company: company} do
      # recipient
      nu = insert(:user, %{company_id: company.id})
      recipient = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {iac_doc, _, rdc, assignment, iac_assigned_form} = insert_iac_fill(us_user, company, recipient)
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)

      resp = json_response(conn, 200)
      assert resp["iac_assigned_form_id"] == iac_assigned_form.id
    end

    @tag :requestor
    test "non-existent template returns 403", %{conn: conn} do
      conn = get(conn, "/n/api/v1/template/0?type=requestor")
      assert text_response(conn, 403) =~ "Forbidden"
    end

    @tag :requestor
    test "can update a template", %{conn: conn, requestor_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})

      # check that it has the name expected
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name

      # update its name
      conn =
        put(conn, "/n/api/v1/template/#{rd.id}", %{
          "name" => "CHANGED #{rd.name}",
          "description" => "CHANGED #{rd.description}",
          "allow_edits" => rd.editable_during_review,
          "file_retention_period" => rd.file_retention_period
        })

      assert text_response(conn, 200) =~ "OK"

      # check that it has changed
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == "CHANGED #{rd.name}"
      assert json_response(conn, 200)["description"] == "CHANGED #{rd.description}"
    end

    @tag :requestor
    test "can replace a template if not used", %{conn: conn, requestor_company: company} do
      template_fn = build(:upload, iac: true, file_name: @sample_iac_pdf)
      rd = insert(:raw_document, %{company_id: company.id, file_name: template_fn})
      upload = %Plug.Upload{path: @sample_iac_pdf, filename: "bill-of-sale.pdf"}

      # check that it has the name expected
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["file_name"] == template_fn

      conn =
        put(conn, "/n/api/v1/template/#{rd.id}/substitute/file", %{
          "file" => upload
        })

      assert response(conn, 200)
      new_id = json_response(conn, 200)["id"]
      assert new_id != rd.id

      conn = get(conn, "/n/api/v1/template/#{new_id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["file_name"] != template_fn
    end

    @tag :requestor
    test "can replace a template even if used in a checklist", %{
      conn: conn,
      requestor_company: company
    } do
      template_fn = build(:upload, iac: true, file_name: @sample_iac_pdf)
      rd = insert(:raw_document, %{company_id: company.id, file_name: template_fn})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      upload = %Plug.Upload{path: @sample_iac_pdf, filename: "bill-of-sale.pdf"}

      # check that it has the name expected
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["file_name"] == template_fn

      conn =
        put(conn, "/n/api/v1/template/#{rd.id}/substitute/file", %{
          "file" => upload
        })

      assert response(conn, 200)
      new_id = json_response(conn, 200)["id"]
      assert new_id != rd.id

      conn = get(conn, "/n/api/v1/template/#{new_id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["file_name"] != template_fn

      # check that the checklist now has the new id
      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0
      assert r0["id"] == pkg.id
      assert r0["name"] == pkg.title
      assert r0["description"] == pkg.description
      assert length(r0["documents"]) == 1
      assert Enum.at(r0["documents"], 0)["id"] == new_id
    end

    @tag :requestor
    test "can update a template's name using the RAW api", %{
      conn: conn,
      requestor_company: company
    } do
      rd = insert(:raw_document, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["id"] == rd.id

      conn =
        put(conn, "/n/api/v1/template-raw/#{rd.id}", %{
          "name" => "CHG#{rd.name}"
        })

      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == "CHG#{rd.name}"
      assert json_response(conn, 200)["id"] == rd.id
    end

    @tag :requestor
    test "access checks for template-raw API", %{
      conn: conn,
      requestor_company: company
    } do
      rd = insert(:raw_document, %{company_id: company.id})
      nc = insert(:company)
      rd2 = insert(:raw_document, %{company_id: nc.id})

      conn =
        put(conn, "/n/api/v1/template-raw/#{rd.id + 1000}", %{
          "name" => "CHG#{rd.name}"
        })

      assert text_response(conn, 403) =~ "Forbidden"

      conn =
        put(conn, "/n/api/v1/template-raw/#{rd2.id}", %{
          "name" => "CHG#{rd.name}"
        })

      assert text_response(conn, 403) =~ "Forbidden"

      conn =
        put(conn, "/n/api/v1/template-raw/#{rd.id}", %{
          "name" => ""
        })

      assert text_response(conn, 403) =~ "Invalid Name"
    end

    @tag :requestor
    test "reset template even if used in a checklist", %{
      conn: conn,
      requestor_company: company
    } do
      template_fn = build(:upload, iac: true, file_name: @sample_iac_pdf)
      rd = insert(:raw_document, %{company_id: company.id, file_name: template_fn})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})

      # check that it has the name expected
      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["name"] == rd.name
      assert json_response(conn, 200)["file_name"] == template_fn

      conn =
        post(conn, "/n/api/v1/template/#{rd.id}/reset", %{})

      assert response(conn, 200)
      new_id = json_response(conn, 200)["id"]
      assert new_id != rd.id

      conn = get(conn, "/n/api/v1/template/#{new_id}?type=requestor")
      assert json_response(conn, 200)["file_name"] == template_fn
      assert json_response(conn, 200)["is_archived"] == false

      conn = get(conn, "/n/api/v1/template/#{rd.id}?type=requestor")
      assert json_response(conn, 200)["is_archived"] == true

      # check that the checklist now has the new id
      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0
      assert r0["id"] == pkg.id
      assert r0["name"] == pkg.title
      assert r0["description"] == pkg.description
      assert length(r0["documents"]) == 1
      assert Enum.at(r0["documents"], 0)["id"] == new_id
    end

    @tag :requestor
    test "cannot archive a non-existent template", %{conn: conn} do
      conn = put(conn, "/n/api/v1/template/archive/0")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "cannot archive a template of other company", %{conn: conn} do
      nc = insert(:company)
      rd = insert(:raw_document, %{company_id: nc.id})

      conn = put(conn, "/n/api/v1/template/archive/#{rd.id}")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "can archive/unarchive a template", %{conn: conn, requestor_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})
      assert rd.is_archived == false

      conn = put(conn, "/n/api/v1/template/archive/#{rd.id}")
      assert text_response(conn, 200) =~ "OK"

      rd_test = Repo.get(RawDocument, rd.id)
      assert rd_test.is_archived == true

      conn = put(conn, "/n/api/v1/template/archive/#{rd.id}")
      assert text_response(conn, 200) =~ "OK"

      rd_test = Repo.get(RawDocument, rd.id)
      assert rd_test.is_archived == false
    end

    @tag :requestor
    test "can upload a template", %{conn: conn} do
      # figure the correct hash
      body = File.read!(@sample_iac_pdf)
      expected_hash = :crypto.hash(:sha3_256, body) |> Base.encode16() |> String.downcase()

      # Do the upload
      upload = %Plug.Upload{path: @sample_iac_pdf, filename: "bill-of-sale.pdf"}

      conn =
        post(conn, "/n/api/v1/template", %{
          "name" => "Bill of Sale",
          "upload" => upload
        })

      assert json_response(conn, 200)
      rdid = json_response(conn, 200)["id"]

      # Check that the file correctly uploaded
      conn = get(conn, "/n/api/v1/template/#{rdid}?type=requestor")
      assert json_response(conn, 200)

      rd = json_response(conn, 200)

      # Check dproxy API
      conn = get(conn, "/n/api/v1/dproxy/#{rd["file_name"]}")
      assert response(conn, 200)

      headers = Enum.into(conn.resp_headers, %{})
      assert Map.has_key?(headers, "content-disposition")
      assert Map.get(headers, "content-disposition") =~ "attachment"

      response_body = response(conn, 200)
      actual_hash = :crypto.hash(:sha3_256, response_body) |> Base.encode16() |> String.downcase()
      assert expected_hash == actual_hash

      # check further dproxy stuff
      conn = get(conn, "/n/api/v1/dproxy/#{rd["file_name"]}?dispName=blpttest")
      assert response(conn, 200)

      headers = Enum.into(conn.resp_headers, %{})
      assert Map.has_key?(headers, "content-disposition")
      assert Map.has_key?(headers, "x-boilerplate-filename")
      assert Map.get(headers, "content-disposition") =~ "attachment"
      assert Map.get(headers, "content-disposition") =~ "blpttest"
    end

    @tag :requestor
    test "dproxy can print", %{conn: conn} do
      template_fn = build(:upload, iac: true, file_name: @sample_iac_pdf)

      # figure the correct hash
      body = File.read!(@sample_iac_pdf)
      expected_hash = :crypto.hash(:sha3_256, body) |> Base.encode16() |> String.downcase()

      conn = get(conn, "/n/api/v1/dproxy/#{template_fn}?print=true")
      assert response(conn, 200)
      headers = Enum.into(conn.resp_headers, %{})
      assert Map.has_key?(headers, "content-disposition")
      assert Map.get(headers, "content-disposition") =~ "inline"
      assert Map.has_key?(headers, "x-boilerplate-filename")

      response_body = response(conn, 200)
      actual_hash = :crypto.hash(:sha3_256, response_body) |> Base.encode16() |> String.downcase()
      assert expected_hash == actual_hash
    end

    @tag :recipient
    test "recipient cannot archive a template", %{conn: conn, recipient_company: company} do
      rd = insert(:raw_document, %{company_id: company.id})
      assert rd.is_archived == false

      conn = put(conn, "/n/api/v1/template/archive/#{rd.id}")
      assert text_response(conn, 403) =~ "forbidden"

      rd_test = Repo.get(RawDocument, rd.id)
      assert rd_test.is_archived == false
    end
  end
end
