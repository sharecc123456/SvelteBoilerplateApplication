defmodule BoilerPlateWeb.NotificationControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  describe "Notification controller API" do
    @tag :requestor
    test "there are no notification by default", %{conn: conn} do
      conn = get(conn, "/n/api/v1/notifications")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "get unread notification count", %{
      conn: conn,
      requestor_company: company,
      requestor_user: us_user
    } do
      insert(:notification, %{user_id: us_user.id, company_id: company.id, flags: 0})

      conn = get(conn, "/n/api/v1/notifications/unread")
      assert json_response(conn, 200) == %{"count" => 1, "unread" => true}

      conn = get(conn, "/n/api/v1/notifications")

      actual = json_response(conn, 200)
      assert length(actual) == 1
      assert Enum.at(actual, 0)["read"] == false
    end

    @tag :requestor
    test "mark notification as read", %{
      conn: conn,
      requestor_company: company,
      requestor_user: us_user
    } do
      notification =
        insert(:notification, %{user_id: us_user.id, company_id: company.id, flags: 0})

      conn = get(conn, "/n/api/v1/notifications/unread")
      assert json_response(conn, 200) == %{"count" => 1, "unread" => true}

      conn = put(conn, "/n/api/v1/notification/#{notification.id}/markread")

      assert text_response(conn, 200)

      conn = get(conn, "/n/api/v1/notifications/unread")
      assert json_response(conn, 200) == %{"count" => 0, "unread" => false}
    end

    @tag :requestor
    test "archive notification", %{
      conn: conn,
      requestor_company: company,
      requestor_user: us_user
    } do
      notification =
        insert(:notification, %{user_id: us_user.id, company_id: company.id, flags: 0})

      conn = get(conn, "/n/api/v1/notifications")
      assert length(json_response(conn, 200)) == 1

      conn = put(conn, "/n/api/v1/notification/#{notification.id}/archive")

      assert text_response(conn, 200)

      conn = get(conn, "/n/api/v1/notifications")
      assert json_response(conn, 200) == []
    end

    @tag :instance_admin
    test "create internal notification", %{conn: conn} do
      conn =
        post(conn, "/internal/notification", %{
          "title" => "Testing",
          "message" => "testing internal"
        })

      assert text_response(conn, 200) == "OK, sent"

      conn = get(conn, "/n/api/v1/notifications")

      actual = json_response(conn, 200)

      assert length(actual) == 1
      assert Enum.at(actual, 0)["type"] == "internal"
    end

    @tag :requestor
    test "cannot access if nmot instance admin", %{conn: conn} do
      conn =
        post(conn, "/internal/notification", %{
          "title" => "Testing",
          "message" => "testing internal"
        })

      assert text_response(conn, 403) =~ "Forbidden"
    end
  end
end
