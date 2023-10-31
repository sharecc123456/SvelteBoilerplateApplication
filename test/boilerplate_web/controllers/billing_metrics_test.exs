defmodule BoilerPlateWeb.BillingMetricsTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  @billing_response %{
    "active_recipients" => 0,
    "checklists_sent" => 0,
    "data_inputs" => 0,
    "files_uploaded" => 0,
    "forms_answered" => 0,
    "forms_processed" => 0,
    "generic_documents_processed" => 0,
    "rspec_documents_processed" => 0,
    "signature_processed" => 0,
    "task_completed" => 0,
    "total" => 0,
    "deleted_recipients" => 0,
    "total_recipients" => 0
  }

  describe "Billing metrics API" do
    @tag :requestor
    test "there are no metrics by default", %{conn: conn, requestor_company: company} do
      conn = get(conn, "/n/api/v1/company/#{company.id}/billing/metrics")
      actual = json_response(conn, 200)

      assert actual["current_month"] == @billing_response
      assert actual["current_quarter"] == @billing_response
      assert actual["current_year"] == @billing_response
      assert actual["last_month"] == @billing_response
      assert actual["last_quarter"] == @billing_response
      assert actual["lifetime"] == @billing_response
      assert actual["week"] == @billing_response
      assert actual["file_retention_period"] == -1
    end

    @tag :requestor
    test "cannot access other company's billing metrics", %{
      conn: conn,
      requestor_company: company
    } do
      conn = get(conn, "/n/api/v1/company/#{company.id + 1000}/billing/metrics")
      assert text_response(conn, 403) =~ "Forbidden"
    end

    @tag :requestor
    test "get active recipient count", %{conn: conn, requestor_company: company} do
      nu = insert(:user, %{company_id: company.id})
      insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/company/#{company.id}/billing/metrics")

      actual = json_response(conn, 200)

      assert actual["current_month"] == %{@billing_response | "active_recipients" => 1, "total_recipients" => 1}
      assert actual["current_quarter"] == %{@billing_response | "active_recipients" => 1, "total_recipients" => 1}
      assert actual["current_year"] == %{@billing_response | "active_recipients" => 1, "total_recipients" => 1}
      assert actual["last_month"] == @billing_response
      assert actual["last_quarter"] == @billing_response
      assert actual["lifetime"] == %{@billing_response | "active_recipients" => 1, "total_recipients" => 1}
      assert actual["week"] == %{@billing_response | "active_recipients" => 1, "total_recipients" => 1}
      assert actual["file_retention_period"] == -1
    end

    @tag :requestor
    test "get deleted recipient count", %{conn: conn, requestor_company: company} do
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      delete(conn, "/n/api/v1/recipient/#{nr.id}")
      conn = get(conn, "/n/api/v1/company/#{company.id}/billing/metrics")

      actual = json_response(conn, 200)

      assert actual["current_month"] == %{@billing_response | "deleted_recipients" => 1, "total_recipients" => 1}
      assert actual["current_year"] == %{@billing_response | "deleted_recipients" => 1, "total_recipients" => 1}
      assert actual["last_month"] == @billing_response
      assert actual["last_quarter"] == @billing_response
      assert actual["lifetime"] == %{@billing_response | "deleted_recipients" => 1, "total_recipients" => 1}
      assert actual["week"] == %{@billing_response | "deleted_recipients" => 1, "total_recipients" => 1}
      assert actual["file_retention_period"] == -1
    end

    @tag :requestor
    test "get checklist count and total count", %{conn: conn, requestor_company: company} do
      # recipient
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      # raw_doc -> generic
      rd = insert(:raw_document, %{company_id: company.id})

      # package
      pkg = insert(:packages, %{templates: [rd.id], company_id: company.id})

      # package contents
      pc =
        insert(:package_contents, %{recipient_id: nr.id, documents: [rd.id], package_id: pkg.id})

      # package_assignments
      insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })

      conn = get(conn, "/n/api/v1/company/#{company.id}/billing/metrics")

      actual = json_response(conn, 200)

      assert actual["current_month"] == %{
               @billing_response
               | "active_recipients" => 1,
                 "checklists_sent" => 1,
                 "generic_documents_processed" => 1,
                 "total" => 1,
                 "total_recipients" => 1
             }

      assert actual["current_quarter"] == %{
               @billing_response
               | "active_recipients" => 1,
                 "checklists_sent" => 1,
                 "generic_documents_processed" => 1,
                 "total" => 1,
                 "total_recipients" => 1
             }

      assert actual["current_year"] == %{
               @billing_response
               | "active_recipients" => 1,
                 "checklists_sent" => 1,
                 "generic_documents_processed" => 1,
                 "total" => 1,
                 "total_recipients" => 1
             }

      assert actual["last_month"] == @billing_response
      assert actual["last_quarter"] == @billing_response

      assert actual["lifetime"] == %{
               @billing_response
               | "active_recipients" => 1,
                 "checklists_sent" => 1,
                 "generic_documents_processed" => 1,
                 "total" => 1,
                 "total_recipients" => 1
             }

      assert actual["week"] == %{
               @billing_response
               | "active_recipients" => 1,
                 "checklists_sent" => 1,
                 "generic_documents_processed" => 1,
                 "total" => 1,
                 "total_recipients" => 1
             }

      assert actual["file_retention_period"] == -1
    end

    @tag :requestor
    test "set file rentention period for requestor", %{conn: conn, requestor_company: company} do
      conn =
        post(conn, "/n/api/v1/company/set-file-retention", %{
          "file_retention_period" => 100,
          "company_id" => company.id
        })

      assert json_response(conn, 200)

      conn = get(conn, "/n/api/v1/company/#{company.id}/billing/metrics")
      assert json_response(conn, 200)["file_retention_period"] == 100
    end

    @tag :requestor
    test "cannot add to other company's retention period", %{
      conn: conn,
      requestor_company: company
    } do
      conn =
        post(conn, "/n/api/v1/company/set-file-retention", %{
          "file_retention_period" => 10010,
          "company_id" => company.id + 1000
        })

      assert text_response(conn, 403) =~ "Forbidden"
    end
  end
end
