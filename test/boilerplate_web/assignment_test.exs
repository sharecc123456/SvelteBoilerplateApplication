defmodule BoilerPlateWeb.AssignmentTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory
  alias BoilerPlate.Repo
  alias BoilerPlate.Recipient
  alias BoilerPlate.PackageContents
  alias BoilerPlate.PackageAssignment

  describe "Contents API" do
    @tag :requestor
    test "no contents exists by default", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      assert text_response(conn, 404) =~ "Not Found"
    end

    @tag :requestor
    test "create contents for empty package", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title
      contents_id = json_response(conn, 200)["id"]

      # check that we get the same contents
      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      assert json_response(conn, 200)["id"] == contents_id
      assert json_response(conn, 200)["documents"] == []

      # check the recipient is correct
      recipient = json_response(conn, 200)["recipient"]
      assert recipient["id"] == nr.id
      assert recipient["name"] == nr.name
      assert recipient["email"] == nu.email
    end

    @tag :requestor
    test "create contents for package with a generic template", %{
      conn: conn,
      requestor_company: company
    } do
      rd = insert(:raw_document, %{company_id: company.id})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title
      contents_id = json_response(conn, 200)["id"]

      # check that we get the same contents
      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      assert json_response(conn, 200)["id"] == contents_id
      assert length(json_response(conn, 200)["documents"]) == 1
      assert Enum.at(json_response(conn, 200)["documents"], 0)["id"] == rd.id
    end

    @tag :requestor
    test "create contents for package with tags", %{
      conn: conn,
      requestor_company: company
    } do
      tag1 = insert(:recipient_tags).id
      tag2 = insert(:recipient_tags).id
      rd = insert(:raw_document, %{company_id: company.id})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id], tags: [tag1, tag2]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title
      contents_id = json_response(conn, 200)["id"]


      # check that we get the same contents
      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      resp = json_response(conn, 200)

      assert resp["id"] == contents_id
      assert Enum.map(resp["tags"], &(&1["id"])) == [tag1, tag2]
    end

    @tag :requestor
    test "create contents for package with a file request", %{
      conn: conn,
      requestor_company: company
    } do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      nfr = insert(:document_request, %{packageid: pkg.id})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title
      contents_id = json_response(conn, 200)["id"]

      # check that we get the same contents
      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      assert json_response(conn, 200)["id"] == contents_id
      assert json_response(conn, 200)["documents"] == []
      assert length(json_response(conn, 200)["requests"]) == 1
      assert Enum.at(json_response(conn, 200)["requests"], 0)["id"] != nfr.id
      assert Enum.at(json_response(conn, 200)["requests"], 0)["name"] == nfr.title
      assert Enum.at(json_response(conn, 200)["requests"], 0)["type"] == "file"
      assert Enum.at(json_response(conn, 200)["requests"], 0)["description"] == nfr.description
    end

    @tag :requestor
    test "can get a contents by its id", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title
      contents_id = json_response(conn, 200)["id"]

      conn = get(conn, "/n/api/v1/contents/#{contents_id}")
      assert json_response(conn, 200)["id"] == contents_id

      conn = get(conn, "/n/api/v1/contents/#{contents_id + 1000}")
      assert text_response(conn, 404) =~ "Not Found"
    end

    @tag :recipient
    test "recipient cannot query contents by ID", %{conn: conn, recipient_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      nc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})

      conn = get(conn, "/n/api/v1/contents/#{nc.id}")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "contents do not cross contaminate", %{conn: conn} do
      nc = insert(:company)
      pkg = insert(:packages, %{company_id: nc.id})
      nu = insert(:user, %{company_id: nc.id})
      nr = insert(:recipient, %{company_id: nc.id, user_id: nu.id})
      ncon = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})

      conn = get(conn, "/n/api/v1/contents/#{ncon.id}")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "creating a contents, restores the recipient", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id, status: 1})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      assert json_response(conn, 200)["title"] == pkg.title

      recp = Repo.get(Recipient, nr.id)
      assert recp.status == 0
    end

    @tag :requestor
    test "can update a contents", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      contents = insert_contents(conn, nr, pkg)

      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})

      conn =
        put(conn, "/n/api/v1/contents/#{contents.id}", %{
          "documents" => [rd.id],
          "requests" => [],
          "title" => contents.title,
          "description" => contents.description,
          "forms" => []
        })

      assert text_response(conn, 200) =~ "OK"

      contents = Repo.get(PackageContents, contents.id)
      assert contents != nil
      assert contents.documents == [rd.id]
    end
  end

  describe "Assignment API" do
    @tag :requestor
    test "can remind on an assignment", %{
      conn: conn,
      requestor_company: company,
      requestor: req
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {ass, _} =
        insert_contents(conn, nr, pkg)
        |> assign_it(conn)

      assert ass.reminder_state["total_count"] == 0

      conn =
        post(conn, "/n/api/v1/checklist/remind", %{
          "checklistId" => ass.id,
          "recipientId" => nr.id,
          "remindMessage" => "Test The World!"
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      ass = Repo.get(PackageAssignment, ass.id)

      assert ass.reminder_state["total_count"] == 1
      assert ass.reminder_state["send_by"] == req.name
    end

    @tag :requestor
    test "can assign a package with 1 generic template", %{
      conn: conn,
      requestor_company: company,
      requestor: requestor
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      contents = insert_contents(conn, nr, pkg)
      assert contents.status == 2

      conn =
        post(conn, "/n/api/v1/assignment", %{
          "enforceDueDate" => false,
          "dueDays" => 1,
          "contentsId" => contents.id,
          "append_note" => "appendNote",
          "checklistIdentifier" => "test"
        })

      assert text_response(conn, 200) =~ "OK"

      assert Repo.aggregate(PackageAssignment, :count) == 1
      ass = Repo.one(PackageAssignment)
      assert ass.contents_id == contents.id
      assert ass.company_id == company.id
      assert ass.recipient_id == nr.id
      assert ass.requestor_id == requestor.id
      assert ass.append_note == "appendNote"

      contents = Repo.get(PackageContents, contents.id)
      assert contents.status == 0
      assert contents.req_checklist_identifier == "test"
    end
  end

  # cl: number of checklists
  # gen: number of generic in the checklist
  # fr: number of file requests
  # rsd: number of RSDs
  # f: number of forms
  #
  # ie. 1gen0fr0rsd0f => the checklist being assigned has 1 generic, 0 file
  #                      requests, 0 rsds, 0 forms
  describe "Dashboard API" do
    @tag :requestor
    test "1gen0fr0rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end

    @tag :requestor
    test "1gen0fr1rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      upl2 = build(:upload, iac: true)
      rd2 = insert(:raw_document, %{flags: 2, company_id: company.id, file_name: upl2})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id, rd2.id]})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end

    @tag :requestor
    test "1gen1fr0rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      insert(:document_request, %{packageid: pkg.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end

    @tag :requestor
    test "1gen2fr0rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})
      insert(:document_request, %{packageid: pkg.id})
      insert(:document_request, %{packageid: pkg.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end

    @tag :requestor
    test "2gen2fr0rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      rd2 = insert(:raw_document, %{company_id: company.id, file_name: upl})
      tag1 = insert(:recipient_tags).id
      tag2 = insert(:recipient_tags).id
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id, rd2.id], tags: [tag1, tag2]})
      insert(:document_request, %{packageid: pkg.id})
      insert(:document_request, %{packageid: pkg.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end

    @tag :requestor
    test "2cl2gen2fr0rsd0f: check that once assigned, it appears on the dashboard", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      rd2 = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id, rd2.id]})
      insert(:document_request, %{packageid: pkg.id})
      insert(:document_request, %{packageid: pkg.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)

      # assign again
      insert_contents(conn, nr, pkg)
      |> commit_contents(conn)
      |> assign_it(conn)
      |> verify_dashboard(conn)
    end
  end
end
