defmodule BoilerPlateWeb.IACControllerTest do
  use BoilerPlateWeb.ConnCase
  alias BoilerPlate.IACDocument
  alias BoilerPlate.IACMasterForm
  alias BoilerPlate.IACField
  alias BoilerPlate.IACLabel
  alias BoilerPlate.Repo
  import BoilerPlate.Factory
  import Ecto.Query

  @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"
  @sample_png "test/fixtures/duck.png"
  @sample_iac_pdf_field_count 21

  describe "IAC Setup API" do
    @tag :requestor
    test "can get the IAC document for a new template", %{
      conn: conn,
      requestor_company: company
    } do
      iac_fn = build(:upload, iac: true)

      rd =
        insert(:raw_document, %{
          file_name: iac_fn,
          company_id: company.id
        })

      conn = get(conn, "/n/api/v1/iac?type=template&id=#{rd.id}")
      assert json_response(conn, 200)["iacDocumentId"] != 0

      iac_doc_id = json_response(conn, 200)["iacDocumentId"]

      iac_doc = Repo.get(IACDocument, iac_doc_id)
      assert iac_doc.status == 0
      assert iac_doc.document_id == rd.id
      assert iac_doc.document_type == IACDocument.document_type(:raw_document)
    end

    @tag :requestor
    test "if an IAC document exists, it's returned", %{
      conn: conn,
      requestor_company: company
    } do
      iac_fn = build(:upload, iac: true)

      rd =
        insert(:raw_document, %{
          file_name: iac_fn,
          company_id: company.id
        })

      iac_doc =
        insert(:iac_document, %{
          document_type: IACDocument.document_type(:raw_document),
          document_id: rd.id,
          file_name: iac_fn
        })

      conn = get(conn, "/n/api/v1/iac?type=template&id=#{rd.id}")
      assert json_response(conn, 200)["iacDocumentId"] == iac_doc.id
    end

    @tag :recipient
    test "if an IAC document exists, it's not returned to a recipient", %{
      conn: conn,
      recipient_company: company
    } do
      iac_fn = build(:upload, iac: true)

      rd =
        insert(:raw_document, %{
          file_name: iac_fn,
          company_id: company.id
        })

      insert(:iac_document, %{
        document_type: IACDocument.document_type(:raw_document),
        document_id: rd.id,
        file_name: iac_fn
      })

      conn = get(conn, "/n/api/v1/iac?type=template&id=#{rd.id}")
      assert json_response(conn, 403)["error"] =~ "forbidden"
    end

    @tag :requestor
    test "cannot get IAC document for non existent raw document", %{
      conn: conn
    } do
      conn = get(conn, "/n/api/v1/iac?type=template&id=0")
      assert json_response(conn, 404)["error"] =~ "not_found"
    end

    @tag :requestor
    test "cannot show non-existent IAC document", %{conn: conn} do
      conn = get(conn, "/n/api/v1/iac/0")
      assert text_response(conn, 404) =~ "notfound"
    end

    @tag :requestor
    test "IAC document can be setup", %{
      conn: conn,
      requestor_company: company
    } do
      iac_fn = build(:upload, file_name: @sample_iac_pdf, iac: true)

      rd =
        insert(:raw_document, %{
          file_name: iac_fn,
          company_id: company.id
        })

      iac_doc =
        insert(:iac_document, %{
          document_type: IACDocument.document_type(:raw_document),
          document_id: rd.id,
          file_name: iac_fn
        })

      conn = post(conn, "/n/api/v1/iac/#{iac_doc.id}/setup")
      assert text_response(conn, 200) =~ "OK"

      # Check that all 21 fields were correctly detected
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)["id"] == iac_doc.id

      resp = json_response(conn, 200)
      assert length(resp["fields"]) == @sample_iac_pdf_field_count
    end

    @tag :requestor
    test "IAC setup of a non-PDF ends up with zero fields", %{
      conn: conn,
      requestor_company: company
    } do
      iac_fn = build(:upload, file_name: @sample_png, iac: true)

      rd =
        insert(:raw_document, %{
          file_name: iac_fn,
          company_id: company.id
        })

      iac_doc =
        insert(:iac_document, %{
          document_type: IACDocument.document_type(:raw_document),
          document_id: rd.id,
          file_name: iac_fn
        })

      conn = post(conn, "/n/api/v1/iac/#{iac_doc.id}/setup")
      assert text_response(conn, 200) =~ "OK"

      # Check that all 21 fields were correctly detected
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)["id"] == iac_doc.id

      resp = json_response(conn, 200)
      assert resp["fields"] == []
    end
  end

  describe "IAC Label API" do
    @tag :requestor
    test "labels can be listed", %{conn: conn} do
      for _ <- 1..100, do: insert(:iac_label)

      conn = get(conn, "/n/api/v1/iac/labels")
      assert json_response(conn, 200)
      assert length(json_response(conn, 200)) == 100
    end

    @tag :requestor
    test "no leak between companies", %{conn: conn, requestor_company: company} do
      my = insert(:iac_label, %{company_id: company.id})
      nc = insert(:company)
      insert(:iac_label, %{company_id: nc.id})

      conn = get(conn, "/n/api/v1/iac/labels")
      assert length(json_response(conn, 200)) == 1

      assert Enum.at(json_response(conn, 200), 0) == %{
               "value" => my.value,
               "question" => my.question,
               "type" => "custom"
             }

      assert Repo.aggregate(IACLabel, :count) == 2
    end

    @tag :requestor
    test "requestor can ask for specific label", %{conn: conn, requestor_company: company} do
      nl = insert(:iac_label)
      nl2 = insert(:iac_label, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/iac/label?value=#{nl.value}")

      assert json_response(conn, 200) == %{
               "value" => nl.value,
               "question" => nl.question,
               "type" => "internal"
             }

      conn = get(conn, "/n/api/v1/iac/label?value=#{nl2.value}")

      assert json_response(conn, 200) == %{
               "value" => nl2.value,
               "question" => nl2.question,
               "type" => "custom"
             }
    end

    @tag :requestor
    test "cannot ask for non existent label", %{conn: conn} do
      assert Repo.aggregate(IACLabel, :count) == 0
      conn = get(conn, "/n/api/v1/iac/label?value=blablabla")
      assert text_response(conn, 404) =~ "not found"
    end

    @tag :requestor
    test "invalid state, same label exists twice", %{conn: conn} do
      insert(:iac_label, %{value: "test_label"})
      insert(:iac_label, %{value: "test_label"})

      assert Repo.aggregate(IACLabel, :count) == 2
      conn = get(conn, "/n/api/v1/iac/label?value=test_label")
      assert text_response(conn, 400) =~ "too many"
    end

    @tag :requestor
    test "requestor can commit labels", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, _} = insert_iac_setup(us_user, company, with_labels: true)

      conn =
        post(conn, "/n/api/v1/iac/labels", %{
          "iacDocId" => iac_doc.id
        })

      assert text_response(conn, 200) =~ "OK"
      assert Repo.aggregate(IACLabel, :count) == @sample_iac_pdf_field_count

      labels = Repo.all(IACLabel)

      for label <- labels do
        field = Repo.get_by(IACField, %{label: label.value})
        assert field != nil
      end

      # check that committing again does not change the count
      conn =
        post(conn, "/n/api/v1/iac/labels", %{
          "iacDocId" => iac_doc.id
        })

      assert text_response(conn, 200) =~ "OK"
      assert Repo.aggregate(IACLabel, :count) == @sample_iac_pdf_field_count
    end

    @tag :recipient
    test "recipient cannot  commit labels", %{conn: conn} do
      conn =
        post(conn, "/n/api/v1/iac/labels", %{
          "iacDocId" => 0
        })

      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :recipient
    test "recipients cannot ask for a label", %{conn: conn} do
      nl = insert(:iac_label)

      conn = get(conn, "/n/api/v1/iac/label?value=#{nl.value}")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :recipient
    test "recipients cannot list labels", %{conn: conn} do
      for _ <- 1..10, do: insert(:iac_label)

      conn = get(conn, "/n/api/v1/iac/labels")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :requestor
    test "access checks for iac_get_labels_of_raw_document", %{
      conn: conn
    } do
      nc = insert(:company)
      rd = insert(:raw_document, %{company_id: nc.id})

      conn = get(conn, "/n/api/v1/iac/labels/#{rd.id}")
      assert text_response(conn, 403) =~ "forbidden"

      conn = get(conn, "/n/api/v1/iac/labels/#{rd.id + 1000}")
      assert text_response(conn, 403) =~ "forbidden"
    end

    @tag :recipient
    test "recipient access checks for iac_get_labels_of_raw_document", %{
      conn: conn,
      recipient_company: company
    } do
      rd = insert(:raw_document, %{company_id: company.id})

      conn = get(conn, "/n/api/v1/iac/labels/#{rd.id}")
      assert text_response(conn, 403) =~ "forbidden"
    end
  end

  describe "IAC Field API" do
    @tag :requestor
    test "IAC setup loader works", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, _} = insert_iac_setup(us_user, company)
      assert iac_doc != nil

      # Check that all 21 fields were correctly detected
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)["id"] == iac_doc.id

      resp = json_response(conn, 200)
      assert length(resp["fields"]) == @sample_iac_pdf_field_count
    end

    @tag :requestor
    test "Can get info of a field", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, iacmfid} = insert_iac_setup(us_user, company)
      iacmf = Repo.get(IACMasterForm, iacmfid)
      assert iacmf != nil
      assert iac_doc.master_form_id == iacmf.id

      fields = iacmf.fields
      test_field = Repo.get(IACField, fields |> Enum.at(0))

      # Test changing location
      conn =
        put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field.id}", %{
          "minY" => test_field.location_value_1 + 100,
          "minX" => test_field.location_value_2 + 100,
          "fieldWidth" => test_field.location_value_3 + 100,
          "fieldHeight" => test_field.location_value_4 + 100,
          "pageNo" => test_field.location_value_6 + 100
        })

      assert json_response(conn, 200)["id"] == test_field.id
      new_loc = json_response(conn, 200)["field"]["location"]["values"]

      assert Enum.at(new_loc, 0) ==
               min(test_field.location_value_1 + 100, test_field.location_value_4 + 100)

      assert Enum.at(new_loc, 1) ==
               min(test_field.location_value_2 + 100, test_field.location_value_3 + 100)

      assert Enum.at(new_loc, 2) ==
               abs(test_field.location_value_3 + 100 - test_field.location_value_2 - 100)

      assert Enum.at(new_loc, 3) ==
               abs(test_field.location_value_4 + 100 - test_field.location_value_1 - 100)

      assert Enum.at(new_loc, 5) == test_field.location_value_6 + 100

      # Now test toggling multiline
      test_field = Repo.get(IACField, test_field.id)

      conn =
        put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field.id}", %{
          "allow_multiline" => not test_field.allow_multiline
        })

      assert json_response(conn, 200)["id"] == test_field.id

      assert json_response(conn, 200)["field"]["allow_multiline"] ==
               not test_field.allow_multiline

      conn =
        put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field.id}", %{
          "allow_multiline" => test_field.allow_multiline
        })

      assert json_response(conn, 200)["id"] == test_field.id

      assert json_response(conn, 200)["field"]["allow_multiline"] ==
               test_field.allow_multiline

      # Test seting label stuff
      conn =
        put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field.id}", %{
          "label" => "test_label",
          "label_value" => "test_label_value",
          "label_question" => "Label Question",
          "label_question_type" => "shortAnswer"
        })

      assert json_response(conn, 200)["id"] == test_field.id
      assert json_response(conn, 200)["field"]["label"] == "test_label"
      assert json_response(conn, 200)["field"]["label_value"] == "test_label_value"
      assert json_response(conn, 200)["field"]["label_question"] == "Label Question"
      assert json_response(conn, 200)["field"]["label_question_type"] == "shortAnswer"

      new_field = Repo.get(IACField, test_field.id)
      assert new_field.label == "test_label"
      assert new_field.label_value == "test_label_value"
      assert new_field.label_question == "Label Question"
      assert new_field.label_question_type == "shortAnswer"

      # Now test that label is part of another API
      conn = get(conn, "/n/api/v1/iac/labels/#{iac_doc.document_id}")
      assert json_response(conn, 200) == ["test_label"]

      # Test chanign the field or fill type
      conn =
        put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field.id}", %{
          "fill_type" => 1337,
          "field_type" => 7000
        })

      assert json_response(conn, 200)["id"] == test_field.id
      assert json_response(conn, 200)["field"]["fill_type"] == 1337
      assert json_response(conn, 200)["field"]["type"] == 7000

      new_field = Repo.get(IACField, test_field.id)
      assert new_field.fill_type == 1337
      assert new_field.field_type == 7000
    end

    @tag :requestor
    test "a field can be added and deleted", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, _} = insert_iac_setup(us_user, company)

      conn =
        post(conn, "/n/api/v1/iac/#{iac_doc.id}/field", %{
          "fieldType" => 1,
          "fill_type" => 0,
          "baseX" => 0,
          "baseY" => 0,
          "finalX" => 0,
          "finalY" => 0,
          "pageNumber" => 0
        })

      assert json_response(conn, 200)

      field_id = json_response(conn, 200)["id"]
      iacf = Repo.get(IACField, field_id)
      assert iacf != nil

      assert iacf.field_type == 1

      # Check that the field is part of the IAC document.
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)["id"] == iac_doc.id

      resp = json_response(conn, 200)
      assert length(resp["fields"]) == @sample_iac_pdf_field_count + 1

      # Now delete the field
      conn = delete(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{field_id}")
      assert text_response(conn, 200) =~ "OK"

      # It's a gone!
      conn = get(conn, "/n/api/v1/iac/#{iac_doc.id}")
      assert json_response(conn, 200)["id"] == iac_doc.id

      resp = json_response(conn, 200)
      assert length(resp["fields"]) == @sample_iac_pdf_field_count
    end

    @tag :recipient
    test "access checks for field delete API", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id})
      insert(:requestor, %{user_id: nu.id, company_id: nc.id})

      {iac_doc, imfid} = insert_iac_setup(nu, nc)
      imf = Repo.get(IACMasterForm, imfid)
      test_field = imf.fields |> Enum.at(0)

      # Now delete the field
      conn = delete(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{test_field}")
      assert text_response(conn, 403) =~ "Forbidden"
    end
  end

  describe "IAC Save FILL" do
    @tag :requestor
    test "IAC save first version of document", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      nu = insert(:user, %{company_id: company.id})
      recipient = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {iac_doc, _, rdc, assignment, iac_assigned_form} = insert_iac_fill(us_user, company, recipient)

      conn =
        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

      assert text_response(conn, 200)

      saved_rdc =
        Repo.one(
          from r in BoilerPlate.RawDocumentCustomized,
            where:
              r.contents_id == ^iac_doc.contents_id and r.recipient_id == ^recipient.id and
                r.raw_document_id == ^iac_doc.raw_document_id,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      assert saved_rdc.version == 1
    end

    @tag :requestor
    test "IAC save second version of document", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      nu = insert(:user, %{company_id: company.id})
      recipient = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {iac_doc, _, rdc, assignment, iac_assigned_form} = insert_iac_fill(us_user, company, recipient)
      conn =
        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

      assert text_response(conn, 200)

      saved_rdc =
        Repo.one(
          from r in BoilerPlate.RawDocumentCustomized,
            where:
              r.contents_id == ^iac_doc.contents_id and r.recipient_id == ^recipient.id and
                r.raw_document_id == ^iac_doc.raw_document_id,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      assert saved_rdc.version == 1

      # TODO: the created and updated date for the two documents are identical, adding a wait time to fix that
      # open for suggestions to make it efficient-callbacks
      Process.sleep(1000)

      conn =
        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

      assert text_response(conn, 200)

      saved_rdc =
        Repo.one(
          from r in BoilerPlate.RawDocumentCustomized,
            where:
              r.contents_id == ^iac_doc.contents_id and r.recipient_id == ^recipient.id and
                r.raw_document_id == ^iac_doc.raw_document_id,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      IO.inspect(saved_rdc)
      assert saved_rdc.version == 2
    end

    @tag :requestor
    test "IAC save forth version of document", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      nu = insert(:user, %{company_id: company.id})
      recipient = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      {iac_doc, _, rdc, assignment, iac_assigned_form} = insert_iac_fill(us_user, company, recipient)

      conn =
        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

        Process.sleep(1000)

        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

        Process.sleep(1000)

        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

        Process.sleep(1000)

        post(conn, "/n/api/v1/iac/#{iac_doc.id}/save", %{
          "id" => iac_doc.id,
          "assignmentId" => assignment.contents_id,
          "fields" => [],
          "type" => "requestor"
        })

      assert text_response(conn, 200)

      saved_rdc =
        Repo.one(
          from r in BoilerPlate.RawDocumentCustomized,
            where:
              r.contents_id == ^iac_doc.contents_id and r.recipient_id == ^recipient.id and
                r.raw_document_id == ^iac_doc.raw_document_id,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      assert saved_rdc.version == 4
    end
  end
end
