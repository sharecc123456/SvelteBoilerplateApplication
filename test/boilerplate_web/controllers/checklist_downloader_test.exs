defmodule BoilerPlateWeb.ChecklistDownloaderTests do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  describe "Checklist Downloader API" do
    @tag :requestor
    test "Success download", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})

      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })

      conn = get(conn, "/completedchecklist/#{na.id}/download")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
    end

    @tag :requestor
    test "No download if company doesnot match", %{conn: conn} do
      company = insert(:company)
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})

      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })

      conn = get(conn, "/completedchecklist/#{na.id}/download")
      assert text_response(conn, 403) =~ "Forbidden"
    end
  end

  describe "Recipient All checklist Downloader API" do
    @tag :requestor
    test "Success download", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})
      pc_2 = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})
      pc_3 = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id})


      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })

      na_1 = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc_2.id,
        package_id: pkg.id,
        company_id: company.id
      })

      na_2 = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc_3.id,
        package_id: pkg.id,
        company_id: company.id
      })

      conn = get(conn, "/checklists/recipient/#{nr.id}/download")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
    end

    @tag :requestor
    test "No download if zero assignments for recipient", %{conn: conn} do
      company = insert(:company)
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/checklists/recipient/#{nr.id}/download")
      assert text_response(conn, 403) =~ "Forbidden"
    end
  end
end
