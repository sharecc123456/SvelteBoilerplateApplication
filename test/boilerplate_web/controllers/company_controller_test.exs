defmodule BoilerPlateWeb.CompanyControllerTest do
  use BoilerPlateWeb.ConnCase
  alias BoilerPlate.Company
  alias BoilerPlate.Repo
  require Logger

  describe "company admins" do
    @tag :recipient
    test "access: recipients have no access", %{conn: conn} do
      conn = get(conn, "/n/api/v1/company/0/admin")

      assert response(conn, 403)
    end

    @tag :requestor
    test "test API returns no other admins", %{conn: conn} do
      conn = get(conn, "/n/api/v1/company/0/admin")

      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "test API returns proper data", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      # Insert another Requestor
      other_admin_user =
        BoilerPlate.Repo.insert!(%BoilerPlate.User{
          name: "2ndTesting User",
          email: "test2@cetlie.hu",
          organization: company.name,
          company_id: company.id,
          admin_of: company.id,
          verified: true
        })

      BoilerPlate.Repo.insert!(%BoilerPlate.Requestor{
        user_id: other_admin_user.id,
        company_id: company.id,
        status: 0,
        name: other_admin_user.name,
        organization: company.name,
        terms_accepted: true,
        esign_consented: false
      })

      conn = get(conn, "/n/api/v1/company/0/admin")

      r = json_response(conn, 200)
      assert length(r) == 1

      os = Enum.at(r, 0)
      assert os["email"] == other_admin_user.email
      assert os["name"] == other_admin_user.name
      assert os["company"] == company.name
    end
  end
end
