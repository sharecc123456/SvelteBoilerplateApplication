defmodule BoilerPlateWeb.IACSignatureTest do
  use BoilerPlateWeb.ConnCase
  alias BoilerPlate.IACSignature
  alias BoilerPlate.PackageContents
  alias BoilerPlate.IACDocument
  alias BoilerPlate.IACMasterForm
  alias BoilerPlate.IACField
  alias BoilerPlate.IACLabel
  alias BoilerPlate.Repo
  import BoilerPlate.Factory

  @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"
  @sample_png "test/fixtures/duck.png"
  @sample_iac_pdf_field_count 21

  describe "IAC Signature Delete API" do
    @tag :requestor
    test "Requestor Filled one Signature delete", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, iacmfid} = insert_iac_setup(us_user, company, with_labels: true)
      iacmf = Repo.get(IACMasterForm, iacmfid)

      fields = iacmf.fields
      field_id = Enum.at(fields, 0)

      put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{field_id}", %{
        "fill_type" => 1
      })

      post(conn, "/n/api/v1/iac/#{field_id}/signature", %{
        "audit_start" => "_as",
        "audit_end" => "_ae",
        "data" => "sigData ...",
        "isreq" => true,
        "save_signature" => true
      })

      insert(:iac_assigned_form, %{
        company_id: company.id,
        contents_id: iac_doc.contents_id,
        master_form_id: iacmf.id,
        recipient_id: 100,
        fields: [field_id],
      })

      assert Repo.get_by(IACSignature, %{signature_field: field_id}) != nil

      conn = delete(conn, "/n/api/v1/iac/signatures", %{
        "fieldIds" => [field_id],
        "iacDocId" => iac_doc.id,
        "fillType" => "requestor",
      })
      assert json_response(conn, 200)
      assert Repo.get_by(IACSignature, %{signature_field: field_id}) == nil
    end

    @tag :requestor
    test "Invalid signature ids", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, iacmfid} = insert_iac_setup(us_user, company, with_labels: true)
      iacmf = Repo.get(IACMasterForm, iacmfid)

      fields = iacmf.fields
      field_id = Enum.at(fields, 0)

      put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{field_id}", %{
        "fill_type" => 1
      })

      post(conn, "/n/api/v1/iac/#{field_id}/signature", %{
        "audit_start" => "_as",
        "audit_end" => "_ae",
        "data" => "sigData ...",
        "isreq" => true,
        "save_signature" => true
      })

      insert(:iac_assigned_form, %{
        company_id: company.id,
        contents_id: iac_doc.contents_id,
        master_form_id: iacmf.id,
        recipient_id: 100,
        fields: [field_id],
      })

      isign = Repo.get_by(IACSignature, %{signature_field: field_id})
      assert isign != nil

      conn = delete(conn, "/n/api/v1/iac/signatures", %{
        "fieldIds" => [Enum.at(fields, 1)],
        "iacDocId" => iac_doc.id,
        "fillType" => "requestor",
      })
      assert json_response(conn, 404)
      assert Repo.get(IACSignature, isign.id) != nil
    end

    @tag :requestor
    test "Forbidden user type", %{
      conn: conn,
      requestor_user: us_user,
      requestor_company: company
    } do
      {iac_doc, iacmfid} = insert_iac_setup(us_user, company, with_labels: true)
      iacmf = Repo.get(IACMasterForm, iacmfid)

      fields = iacmf.fields
      field_id = Enum.at(fields, 0)

      put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{field_id}", %{
        "fill_type" => 1
      })

      post(conn, "/n/api/v1/iac/#{field_id}/signature", %{
        "audit_start" => "_as",
        "audit_end" => "_ae",
        "data" => "sigData ...",
        "isreq" => true,
        "save_signature" => true
      })

      insert(:iac_assigned_form, %{
        company_id: company.id,
        contents_id: iac_doc.contents_id,
        master_form_id: iacmf.id,
        recipient_id: 100,
        fields: [field_id],
      })

      isign = Repo.get_by(IACSignature, %{signature_field: field_id})
      assert isign != nil

      assert_raise RuntimeError, ~r/^Invalid fill type user tried access/, fn ->
        conn = delete(conn, "/n/api/v1/iac/signatures", %{
          "fieldIds" => [field_id],
          "iacDocId" => iac_doc.id,
          "fillType" => "fake_user",
        })
        assert json_response(conn, 403)
      end
      assert Repo.get(IACSignature, isign.id) != nil
    end

    @tag :recipient
    test "Recipient signature delete", %{
      conn: conn,
      recipient_user: us_user,
      recipient_company: company
    } do
      {iac_doc, iacmfid} = insert_iac_setup(us_user, company, with_labels: true)
      iacmf = Repo.get(IACMasterForm, iacmfid)

      fields = iacmf.fields
      field_id = Enum.at(fields, 0)

      put(conn, "/n/api/v1/iac/#{iac_doc.id}/field/#{field_id}", %{
        "fill_type" => 2
      })

      post(conn, "/n/api/v1/iac/#{field_id}/signature", %{
        "audit_start" => "_as",
        "audit_end" => "_ae",
        "data" => "sigData ...",
        "isreq" => false,
        "save_signature" => true
      })

      insert(:iac_assigned_form, %{
        company_id: company.id,
        contents_id: iac_doc.contents_id,
        master_form_id: iacmf.id,
        recipient_id: 100,
        fields: [field_id],
      })

      conn = delete(conn, "/n/api/v1/iac/signatures", %{
        "fieldIds" => [field_id],
        "iacDocId" => iac_doc.id,
        "fillType" => "recipient",
      })

      assert json_response(conn, 200)
      assert Repo.get_by(IACSignature, %{signature_field: field_id}) == nil
    end
  end
end
