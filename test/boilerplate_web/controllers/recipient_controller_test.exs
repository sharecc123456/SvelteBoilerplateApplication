defmodule BoilerPlateWeb.RecipientControllerTest do
  use BoilerPlateWeb.ConnCase
  alias BoilerPlate.Company
  alias BoilerPlate.Recipient
  alias BoilerPlate.User
  alias BoilerPlate.Repo
  import BoilerPlate.Factory
  require Logger

  ###
  ### Helpers
  ###

  @doc """
  Helper function to query a recipient's data tab and match a label to a value
  """
  def expect_label(conn, nrid, label, val) do
    conn = get(conn, "/n/api/v1/recipient/#{nrid}/data")
    assert response(conn, 200)

    r = json_response(conn, 200)
    assert length(r) > 0

    assert Enum.find_value(r, fn x ->
             if x["label"] == label do
               x["value"]
             else
               nil
             end
           end) == val
  end

  describe "Requestor: Recipient Data API" do
    @tag :requestor
    test "a recipient's data tab should be empty by default", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/data")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "can add data to data tab", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data", %{
          "label" => "TESTLABEL",
          "value" => "TESTVALUE"
        })

      assert text_response(conn, 200) =~ "OK"
      expect_label(conn, nr.id, "TESTLABEL", "TESTVALUE")
    end

    @tag :requestor
    test "can overwrite data in data tab", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data", %{
          "label" => "TESTLABEL",
          "value" => "TESTVALUE"
        })

      assert text_response(conn, 200) =~ "OK"
      expect_label(conn, nr.id, "TESTLABEL", "TESTVALUE")

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data", %{
          "label" => "TESTLABEL",
          "value" => "TESTVALUE2"
        })

      assert text_response(conn, 200) =~ "OK"
      expect_label(conn, nr.id, "TESTLABEL", "TESTVALUE2")
    end

    @tag :requestor
    test "overwriting data should make the old remain in history", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data", %{
          "label" => "TESTLABEL",
          "value" => "TESTVALUE"
        })

      assert text_response(conn, 200) =~ "OK"
      expect_label(conn, nr.id, "TESTLABEL", "TESTVALUE")

      # Whew, FIXME.
      # This is needed because we are too fast - and the inserted_at for both
      # RecipientDatas are the same.
      :timer.sleep(1000)

      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data", %{
          "label" => "TESTLABEL",
          "value" => "TESTVALUE2"
        })

      assert text_response(conn, 200) =~ "OK"
      expect_label(conn, nr.id, "TESTLABEL", "TESTVALUE2")

      # get history
      conn =
        post(conn, "/n/api/v1/recipient/#{nr.id}/data/label/history", %{
          "label" => "TESTLABEL"
        })

      assert response(conn, 200)
      r = json_response(conn, 200)
      assert length(r) == 2

      current_entry = Enum.at(r, 0)
      old_entry = Enum.at(r, 1)

      assert Map.has_key?(current_entry, "label")
      assert current_entry["label"] == "TESTLABEL"
      assert current_entry["value"] == "TESTVALUE2"

      assert Map.has_key?(old_entry, "label")
      assert old_entry["label"] == "TESTLABEL"
      assert old_entry["value"] == "TESTVALUE"
    end

    @tag :requestor
    test "data in a data tab can be queried", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      nd = insert(:recipient_data, %{recipient_id: nr.id})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}/data")
      assert response(conn, 200)

      r = json_response(conn, 200)
      assert length(r) == 1

      r0 = Enum.at(r, 0)
      assert r0["label"] == nd.label
      assert r0["type"] == "shortAnswer"
      assert r0["value"] == nd.value.value
    end
  end

  describe "Access Checks: Recipient Data API" do
    @tag :recipient
    test("a recipient's data cannot be accessed by a recipient", %{conn: conn},
      do: expect_forbidden_get("/n/api/v1/recipient/0/data", conn)
    )

    @tag :recipient
    test("a recipient cannot add data", %{conn: conn},
      do:
        expect_forbidden_post(
          "/n/api/v1/recipient/0/data",
          %{
            "label" => "LL",
            "value" => "VV"
          },
          conn
        )
    )

    @tag :recipient
    test("label history API is forbidden", %{conn: conn},
      do:
        expect_forbidden_post(
          "/n/api/v1/recipient/0/data/label/history",
          %{"label" => "LL"},
          conn
        )
    )
  end

  describe "Recipient API" do
    @tag :requestor
    test "can create a recipient", %{conn: conn} do
      conn =
        post(conn, "/n/api/v1/recipient", %{
          "organization" => "NEWORG",
          "name" => "NEWCONTACT",
          "email" => "new_contact@cetlie.hu",
          "phone_number" => "+15552121234",
          "start_date" => nil
        })

      # get the ID of the newly created recipient
      recp = Repo.get_by(Recipient, %{name: "NEWCONTACT"})
      recp_user = Repo.get_by(User, %{name: "NEWCONTACT"})
      assert recp.organization == "NEWORG"
      assert recp.name == "NEWCONTACT"
      assert recp_user.email == "new_contact@cetlie.hu"
      assert recp.phone_number == "+15552121234"
      assert recp.start_date == nil

      assert json_response(conn, 200) == %{"id" => recp.id}
    end
  end

  @tag :requestor
  test "bulk create API can create a single recipient", %{conn: conn} do
    data = [
      %{
        name: "NEWCONTACT",
        email: "newemail@cetlie.hu",
        organization: "Google, Inc."
      }
    ]

    conn =
      post(conn, "/n/api/v1/recipient/bulk", %{
        "recipients" => data
      })

    assert json_response(conn, 200)
    assert json_response(conn, 200)["success"] == 1
    assert json_response(conn, 200)["failure"] == 0
  end

  @tag :requestor
  test "bulk create API can create multiple recipients", %{conn: conn} do
    data = [
      %{
        name: "NEWCONTACT",
        email: "newemail@cetlie.hu",
        organization: "Google, Inc."
      },
      %{
        name: "NEWCONTACT2",
        email: "newemail2@cetlie.hu",
        organization: "Trello, Inc."
      }
    ]

    conn =
      post(conn, "/n/api/v1/recipient/bulk", %{
        "recipients" => data
      })

    assert json_response(conn, 200)
    assert json_response(conn, 200)["success"] == 2
    assert json_response(conn, 200)["failure"] == 0
  end

  @tag :requestor
  test "bulk create API but with bad data", %{conn: conn} do
    data = [
      %{
        name: "NEWCONTACT",
        email: "",
        organization: "Google, Inc."
      },
      %{
        name: "NEWCONTACT2",
        email: "newemail2@cetlie.hu",
        organization: "Trello, Inc."
      }
    ]

    conn =
      post(conn, "/n/api/v1/recipient/bulk", %{
        "recipients" => data
      })

    assert json_response(conn, 200)
    assert json_response(conn, 200)["success"] == 1
    assert json_response(conn, 200)["failure"] == 1
  end
end
