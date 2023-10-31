defmodule BoilerPlateWeb.ApiControllerTest do
  use BoilerPlateWeb.ConnCase
  alias BoilerPlate.AdhocLink
  alias BoilerPlate.Company
  alias BoilerPlate.Recipient
  alias BoilerPlate.Requestor
  alias BoilerPlate.Package
  alias BoilerPlate.DocumentRequest
  alias BoilerPlate.User
  alias BoilerPlate.Repo
  import BoilerPlate.Factory
  require Logger

  describe "Login API" do
    test "a user with no recipient nor requestor account", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "failed"
             }
    end

    test "a user with a requestor account", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      insert(:requestor, %{company_id: nc.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "requestor"
             }
    end

    test "a user with a recipient account", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      insert(:recipient, %{company_id: nc.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "recipient"
             }
    end

    test "a user with a both accounts", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      insert(:recipient, %{company_id: nc.id, user_id: nu.id})
      insert(:requestor, %{company_id: nc.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "midlogin",
               "choose_requestor" => false
             }
    end

    test "a user with more than one requestor accounts", %{conn: conn} do
      nc = insert(:company)
      nc2 = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      insert(:recipient, %{company_id: nc.id, user_id: nu.id})
      insert(:requestor, %{company_id: nc.id, user_id: nu.id})
      insert(:requestor, %{company_id: nc2.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "midlogin",
               "choose_requestor" => true
             }
    end

    test "a user with a multiple recipients  accounts", %{conn: conn} do
      nc = insert(:company)
      nc2 = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      insert(:recipient, %{company_id: nc.id, user_id: nu.id})
      insert(:recipient, %{company_id: nc2.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "id" => nu.id,
               "name" => nu.name,
               "status" => "recipientc"
             }
    end

    test "a requestor who never logged in", %{conn: conn} do
      nc = insert(:company)
      nu = insert(:user, %{logins_count: 0, company_id: nc.id, password_hash: "test"})
      insert(:requestor, %{company_id: nc.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/login", %{
          "email" => nu.email,
          "hashedPassword" => nu.password_hash
        })

      assert json_response(conn, 200) == %{
               "uid" => nu.id,
               "email" => nu.email,
               "lhash" => nu.password_hash,
               "status" => "reset_password"
             }
    end
  end

  describe "ESIGN Consent APIs" do
    @tag :requestor
    test "requestor: no esign consent by default", %{conn: conn, requestor: requestor} do
      conn = get(conn, "/n/api/v1/esign/consent/#{requestor.id}?userType=requestor")
      assert json_response(conn, 200)["consented"] == false
    end

    @tag :recipient
    test "recipient: no esign consent by default", %{conn: conn, recipient: recipient} do
      conn = get(conn, "/n/api/v1/esign/consent/#{recipient.id}?userType=recipient")
      assert json_response(conn, 200)["consented"] == false
    end

    @tag :recipient
    test "recipient: cannot ask for requestor esign consent", %{conn: conn, recipient: recipient} do
      conn = get(conn, "/n/api/v1/esign/consent/#{recipient.id}?userType=requestor")
      assert text_response(conn, 404) =~ "Not found"
    end

    @tag :recipient
    test "recipient: cannot ask for someone else's esign consent", %{
      conn: conn,
      recipient_company: company
    } do
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/esign/consent/#{nr.id}?userType=recipient")
      assert text_response(conn, 404) =~ "Not found"
    end

    @tag :requestor
    test "requestor: can consent to ESIGN", %{
      conn: conn,
      requestor: requestor
    } do
      conn =
        post(conn, "/n/api/v1/esign/consent", %{
          "userType" => "requestor",
          "recipientId" => requestor.id,
          "consented" => false
        })

      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/esign/consent/#{requestor.id}?userType=requestor")
      assert json_response(conn, 200)["consented"] == false

      conn =
        post(conn, "/n/api/v1/esign/consent", %{
          "userType" => "requestor",
          "recipientId" => requestor.id,
          "consented" => true
        })

      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/esign/consent/#{requestor.id}?userType=requestor")
      assert json_response(conn, 200)["consented"] == true
    end

    @tag :recipient
    test "recipient: can consent to ESIGN", %{
      conn: conn,
      recipient: recipient
    } do
      conn =
        post(conn, "/n/api/v1/esign/consent", %{
          "userType" => "recipient",
          "recipientId" => recipient.id,
          "consented" => false
        })

      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/esign/consent/#{recipient.id}?userType=recipient")
      assert json_response(conn, 200)["consented"] == false

      conn =
        post(conn, "/n/api/v1/esign/consent", %{
          "userType" => "recipient",
          "recipientId" => recipient.id,
          "consented" => true
        })

      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/esign/consent/#{recipient.id}?userType=recipient")
      assert json_response(conn, 200)["consented"] == true
    end

    @tag :recipient
    test "recipient: cannot consent as someone else to ESIGN", %{
      conn: conn
    } do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id, password_hash: "test"})
      nr = insert(:recipient, %{company_id: nc.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/esign/consent", %{
          "userType" => "recipient",
          "recipientId" => nr.id,
          "consented" => true
        })

      assert text_response(conn, 200) =~ "OK"

      nr = Repo.get(Recipient, nr.id)
      assert nr.esign_consented == false
    end
  end

  describe "Shared API" do
    @tag :requestor
    test "can lookup users", %{conn: conn, requestor_user: us_user} do
      conn = get(conn, "/n/api/v1/user/lookup?email=#{us_user.email}")
      assert json_response(conn, 200)["exists"] == true
      assert json_response(conn, 200)["id"] == us_user.id
      assert json_response(conn, 200)["name"] == us_user.name

      conn = get(conn, "/n/api/v1/user/lookup?email=nonexistent@fshdafsad.hu")
      assert json_response(conn, 200)["exists"] == false
    end

    @tag :requestor
    test "requestor: can call user_me API", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      requestor = Repo.get_by(Requestor, %{user_id: us_user.id, status: 0})
      conn = get(conn, "/n/api/v1/user/me?type=requestor")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert r["user_id"] == us_user.id
      assert r["id"] == requestor.id
      assert r["name"] == requestor.name
      assert r["email"] == us_user.email
      assert r["type"] == "requestor"
    end

    @tag :recipient
    test "recipient: can call user_me API", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      recipient = Repo.get_by(Recipient, %{user_id: us_user.id, status: 0})
      conn = get(conn, "/n/api/v1/user/me?type=recipient")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert r["email"] == us_user.email
      assert r["name"] == recipient.name
      assert r["id"] == recipient.id
    end

    @tag :requestor
    test "requestor: user_companies API", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

      # By default, there should be no recipient companies
      conn = get(conn, "/n/api/v1/user/companies")
      assert json_response(conn, 200)["recipient_companies"] == []

      # Add a new company
      nc = insert(:company)
      insert(:recipient, %{user_id: us_user.id, company_id: nc.id})

      # Query again
      conn = get(conn, "/n/api/v1/user/companies")
      assert response(conn, 200)

      r = json_response(conn, 200)["recipient_companies"]
      assert length(r) == 1

      assert Enum.at(r, 0)["id"] == nc.id
      assert Enum.at(r, 0)["name"] == nc.name
    end

    @tag :recipient
    test "recipient: user_companies API", %{conn: conn, recipient_company: c} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

      # By default, there should be 1 company
      conn = get(conn, "/n/api/v1/user/companies")
      assert response(conn, 200)
      r = json_response(conn, 200)["recipient_companies"]
      assert length(r) == 1

      assert Enum.at(r, 0)["id"] == c.id
      assert Enum.at(r, 0)["name"] == c.name

      # Add a new company
      nc = insert(:company)
      insert(:recipient, %{user_id: us_user.id, company_id: nc.id})

      # Query again
      conn = get(conn, "/n/api/v1/user/companies")
      assert response(conn, 200)

      r = json_response(conn, 200)["recipient_companies"]
      assert length(r) == 2

      # Alphabetical ordering - see test/support/factory.ex
      assert Enum.at(r, 0)["id"] == c.id
      assert Enum.at(r, 0)["name"] == c.name
      assert Enum.at(r, 1)["id"] == nc.id
      assert Enum.at(r, 1)["name"] == nc.name
    end
  end

  describe "Requestor Misc APIs" do
    @tag :requestor
    test "can get other requestors", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      requestor = Repo.get_by(Requestor, %{user_id: us_user.id, status: 0})

      conn = get(conn, "/n/api/v1/company/info")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert length(r["requestors"]) == 1

      assert Enum.at(r["requestors"], 0)["requestor_id"] == requestor.id

      nu = insert(:user, %{company_id: requestor.company_id})
      nr = insert(:requestor, %{company_id: requestor.company_id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/company/info")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert length(r["requestors"]) == 2

      original_requestor =
        Enum.find_value(r["requestors"], fn x ->
          if x["requestor_id"] == requestor.id do
            x
          else
            nil
          end
        end)

      new_requestor =
        Enum.find_value(r["requestors"], fn x ->
          if x["requestor_id"] == nr.id do
            x
          else
            nil
          end
        end)

      assert original_requestor != nil
      assert new_requestor != nil
    end

    @tag :recipient
    test("a recipient cannot see other admins", %{conn: conn},
      do: expect_forbidden_get("/n/api/v1/company/info", conn)
    )
  end

  describe "Requestor: Checklist API" do
    @tag :requestor
    test "there are no checklists by default", %{conn: conn} do
      conn = get(conn, "/n/api/v1/checklists")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "a checklist can be listed", %{conn: conn, requestor_company: company} do
      tag1 = insert(:recipient_tags).id
      pkg = insert(:packages, %{company_id: company.id, tags: [tag1]})
      conn = get(conn, "/n/api/v1/checklists")
      assert json_response(conn, 200)

      r = json_response(conn, 200)
      assert length(r) == 1
      r0 = Enum.at(r, 0)

      assert r0["id"] == pkg.id
      assert r0["name"] == pkg.title
      assert r0["description"] == pkg.description
      assert r0["documents"] == pkg.templates
      assert r0["tags"] != nil
      assert Enum.at(r0["tags"], 0)["id"] == tag1
    end

    @tag :requestor
    test "a checklist can be queried by ID", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["name"] == pkg.title
      assert r0["description"] == pkg.description
      assert r0["documents"] == pkg.templates
      assert r0["tags"] != nil
    end

    @tag :requestor
    test "a checklist can be deleted", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})

      conn = delete(conn, "/n/api/v1/checklist/#{pkg.id}")
      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/checklists")
      assert json_response(conn, 200) == []
    end

    @tag :requestor
    test "a checklist in another company cannot be deleted", %{
      conn: conn
    } do
      nc = insert(:company)
      pkg = insert(:packages, %{company_id: nc.id})

      conn = delete(conn, "/n/api/v1/checklist/#{pkg.id}")
      assert json_response(conn, 400)["error"] == "forbidden"
    end

    @tag :requestor
    test "a checklist can be updated", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      tag1 = insert(:recipient_tags).id
      tag2 = insert(:recipient_tags).id

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "CHANGED #{pkg.title}",
          "documents" => [],
          "file_requests" => [],
          "description" => "CHANGED #{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true,
          "tags" => [tag1, tag2]
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["name"] == "CHANGED #{pkg.title}"
      assert r0["description"] == "CHANGED #{pkg.description}"
      assert r0["documents"] == []
      assert length(r0["tags"]) == 2
    end

    @tag :requestor
    test "can add/remove a template to a checklist", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "#{pkg.title}",
          "documents" => [rd.id],
          "file_requests" => [],
          "description" => "#{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert length(r0["documents"]) == 1
      assert Enum.at(r0["documents"], 0)["id"] == rd.id

      # Now remove it
      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "#{pkg.title}",
          "documents" => [],
          "file_requests" => [],
          "description" => "#{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["documents"] == []
    end

    @tag :requestor
    test "cannot add a file request without a name", %{
      conn: conn,
      requestor_company: company
    } do
      pkg = insert(:packages, %{company_id: company.id})

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "#{pkg.title}",
          "documents" => [],
          "file_requests" => [
            %{
              "new" => true,
              "name" => "",
              "description" => "FRTESTBLPTDESC",
              "order" => 0,
              "type" => "file"
            }
          ],
          "description" => "#{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true
        })

      assert text_response(conn, 200) == "OK"

      # but it should not have been added
      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["file_requests"] == []
    end

    @tag :requestor
    test "can add/remove a file request to a checklist", %{
      conn: conn,
      requestor_company: company
    } do
      pkg = insert(:packages, %{company_id: company.id})

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "#{pkg.title}",
          "documents" => [],
          "file_requests" => [
            %{
              "new" => true,
              "name" => "FRTESTBLPT",
              "description" => "FRTESTBLPTDESC",
              "order" => 0,
              "type" => "file"
            }
          ],
          "description" => "#{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert length(r0["file_requests"]) == 1

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "#{pkg.title}",
          "documents" => [],
          "file_requests" => [],
          "description" => "#{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["file_requests"] == []
    end

    @tag :requestor
    test "can remove tags in checklist", %{conn: conn, requestor_company: company} do
      tag1 = insert(:recipient_tags).id
      pkg = insert(:packages, %{company_id: company.id, tags: [tag1]})

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "CHANGED #{pkg.title}",
          "documents" => [],
          "file_requests" => [],
          "description" => "CHANGED #{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true,
          "tags" => []
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["name"] == "CHANGED #{pkg.title}"
      assert r0["description"] == "CHANGED #{pkg.description}"
      assert r0["documents"] == []
      assert length(r0["tags"]) == 0
    end

    @tag :requestor
    test "can add tags in checklist", %{conn: conn, requestor_company: company} do
      tag1 = insert(:recipient_tags).id
      pkg = insert(:packages, %{company_id: company.id, tags: [tag1]})
      tag2 = insert(:recipient_tags).id

      conn =
        put(conn, "/n/api/v1/checklist/#{pkg.id}", %{
          "id" => pkg.id,
          "name" => "CHANGED #{pkg.title}",
          "documents" => [],
          "file_requests" => [],
          "description" => "CHANGED #{pkg.description}",
          "allow_duplicate_submission" => false,
          "allow_mutiple_requests" => false,
          "forms" => [],
          "enforce_due_date" => false,
          "due_days" => 0,
          "due_date_type" => 0,
          "commit" => true,
          "tags" => [tag1, tag2]
        })

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      r0 = json_response(conn, 200)
      assert r0

      assert r0["id"] == pkg.id
      assert r0["name"] == "CHANGED #{pkg.title}"
      assert r0["description"] == "CHANGED #{pkg.description}"
      assert r0["documents"] == []
      assert length(r0["tags"]) == 2
    end

    @tag :requestor
    test "a checklist can be archived/unarchived", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      assert json_response(conn, 200)["id"] == pkg.id
      assert json_response(conn, 200)["is_archived"] == false

      conn = put(conn, "/n/api/v1/checklist/archive/#{pkg.id}")
      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      assert json_response(conn, 200)["id"] == pkg.id
      assert json_response(conn, 200)["is_archived"] == true

      # should not show up in the main query
      conn = get(conn, "/n/api/v1/checklists")
      assert json_response(conn, 200) == []

      conn = put(conn, "/n/api/v1/checklist/archive/#{pkg.id}")
      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/checklist/#{pkg.id}")
      assert json_response(conn, 200)["id"] == pkg.id
      assert json_response(conn, 200)["is_archived"] == false

      conn = get(conn, "/n/api/v1/checklists")
      assert length(json_response(conn, 200)) == 1
    end

    @tag :requestor
    test "an empty checklist can be duplicated", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 200)["new_id"] != pkg.id
      new_pkg = Repo.get(Package, json_response(conn, 200)["new_id"])
      assert new_pkg != nil
      assert new_pkg.title =~ "- Duplicate"
      assert new_pkg.description =~ "- Duplicate"
      assert new_pkg.templates == pkg.templates
      assert new_pkg.company_id == pkg.company_id
    end

    @tag :requestor
    test "a checklist with templates can be duplicated", %{conn: conn, requestor_company: company} do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 200)["new_id"] != pkg.id
      new_pkg = Repo.get(Package, json_response(conn, 200)["new_id"])
      assert new_pkg != nil
      assert new_pkg.title =~ "- Duplicate"
      assert new_pkg.description =~ "- Duplicate"
      assert new_pkg.templates == pkg.templates
      assert new_pkg.company_id == pkg.company_id
    end

    @tag :requestor
    test "a checklist with file requests  can be duplicated", %{
      conn: conn,
      requestor_company: company
    } do
      pkg = insert(:packages, %{company_id: company.id})
      nfr = insert(:document_request, %{packageid: pkg.id})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 200)["new_id"] != pkg.id
      new_pkg = Repo.get(Package, json_response(conn, 200)["new_id"])
      assert new_pkg != nil
      assert new_pkg.title =~ "- Duplicate"
      assert new_pkg.description =~ "- Duplicate"
      assert new_pkg.templates == pkg.templates
      assert new_pkg.company_id == pkg.company_id

      nfr_check = Repo.get_by(DocumentRequest, %{packageid: new_pkg.id})
      assert nfr_check != nil
      assert nfr_check.title == nfr.title
    end

    @tag :requestor
    test "an adhoc link can be made", %{conn: conn, requestor_company: company} do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "intakeLink" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 200)["link"] != nil
      adhoc_link = json_response(conn, 200)["link"]

      ah = Repo.get_by(AdhocLink, %{type_id: pkg.id, type: AdhocLink.atom_to_type(:package)})
      assert ah != nil
      assert adhoc_link =~ ah.adhoc_string
    end

    @tag :requestor
    test "an adhoc link cannot be made if there are RSDs", %{
      conn: conn,
      requestor_company: company
    } do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl, flags: 2})
      pkg = insert(:packages, %{company_id: company.id, templates: [rd.id]})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "intakeLink" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 400) == %{"error" => "intake_with_rsds"}
    end

    @tag :requestor
    test "an adhoc link cannot be made for other company's packages", %{
      conn: conn
    } do
      nc = insert(:company)
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: nc.id, file_name: upl})
      pkg = insert(:packages, %{company_id: nc.id, templates: [rd.id]})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "intakeLink" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 400) == %{"error" => "forbidden"}
    end

    @tag :requestor
    test "access check for checklist duplicate API", %{conn: conn} do
      nc = insert(:company)
      pkg = insert(:packages, %{company_id: nc.id})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 400) == %{"error" => "forbidden"}
    end

    @tag :recipient
    test "recipient access check for checklist duplicate API", %{
      conn: conn,
      recipient_company: company
    } do
      nc = insert(:company)
      pkg = insert(:packages, %{company_id: nc.id})
      pkg2 = insert(:packages, %{company_id: company.id})

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg.id
        })

      assert json_response(conn, 400) == %{"error" => "forbidden"}

      conn =
        post(conn, "/n/api/v1/checklist", %{
          "duplicate" => true,
          "checklistId" => pkg2.id
        })

      assert json_response(conn, 400) == %{"error" => "forbidden"}
    end

    @tag :requestor
    test "access check for checklist archive API", %{conn: conn} do
      nc = insert(:company)
      pkg = insert(:packages, %{company_id: nc.id})

      conn = put(conn, "/n/api/v1/checklist/archive/#{pkg.id}")
      assert text_response(conn, 403) =~ "Forbidden"

      conn = put(conn, "/n/api/v1/checklist/archive/#{pkg.id + 1000}")
      assert text_response(conn, 403) =~ "Forbidden"
    end
  end

  describe "Requestor: Recipient API" do
    @tag :requestor
    test "can hide/show a recipient", %{
      conn: conn,
      requestor_company: company,
      requestor_user: us_user
    } do
      nr = insert(:recipient, %{company_id: company.id, user_id: us_user.id})
      conn = get(conn, "/n/api/v1/recipient/#{nr.id}")
      assert json_response(conn, 200)["show_in_dashboard"] == true

      conn = put(conn, "/n/api/v1/recipient/hide/#{nr.id}")
      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}")
      assert json_response(conn, 200)["show_in_dashboard"] == false

      conn = put(conn, "/n/api/v1/recipient/show/#{nr.id}")
      assert text_response(conn, 200) =~ "OK"

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}")
      assert json_response(conn, 200)["show_in_dashboard"] == true
    end

    @tag :requestor
    test "there are no recipients", %{conn: conn} do
      conn = get(conn, "/n/api/v1/recipients")

      assert json_response(conn, 200) == []
    end

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

    @tag :requestor
    test "can create a recipient that is already a user", %{
      conn: conn,
      requestor_company: company
    } do
      nc = insert(:company)
      nu = insert(:user, %{company_id: nc.id})

      conn =
        post(conn, "/n/api/v1/recipient", %{
          "organization" => "NEWORG",
          "name" => nu.name,
          "email" => nu.email,
          "phone_number" => "+15552121234",
          "start_date" => nil
        })

      recp = Repo.get_by(Recipient, %{user_id: nu.id, company_id: company.id})
      assert recp != nil
      assert recp.status == 0
      assert recp.organization == "NEWORG"
      assert recp.phone_number == "+15552121234"
      assert json_response(conn, 200) == %{"id" => recp.id}
    end

    @tag :requestor
    test "cannot create the same recipient twice", %{conn: conn, requestor_company: company} do
      nu = insert(:user, %{company_id: company.id})
      insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        post(conn, "/n/api/v1/recipient", %{
          "organization" => "NEWORG",
          "name" => nu.name,
          "email" => nu.email,
          "phone_number" => "+15552121234",
          "start_date" => nil
        })

      assert json_response(conn, 400) == %{"error" => "bad_data"}
    end

    @tag :requestor
    test "a recipient can be listed", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipients")
      assert response(conn, 200)

      r = json_response(conn, 200)
      assert length(r) == 1

      r0 = Enum.at(r, 0)
      assert r0["id"] == nr.id
      assert r0["name"] == nr.name
      assert r0["email"] == nu.email
      assert r0["company"] == nr.organization
    end

    @tag :requestor
    test "a recipient can be deleted", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = delete(conn, "/n/api/v1/recipient/#{nr.id}")

      assert response(conn, 200)

      conn = get(conn, "/n/api/v1/recipients")
      assert response(conn, 200)

      r = json_response(conn, 200)
      assert length(r) == 1

      r0 = Enum.at(r, 0)
      assert r0["id"] == nr.id
      assert r0["name"] == nr.name
      assert r0["email"] == nu.email
      assert r0["company"] == nr.organization
      assert r0["deleted"] == true
    end

    @tag :requestor
    test "a recipient can be queried via ID", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipient/#{nr.id}")
      assert response(conn, 200)

      r = json_response(conn, 200)
      assert r["id"] == nr.id
      assert r["name"] == nr.name
      assert r["email"] == nu.email
      assert r["company"] == nr.organization
    end

    @tag :requestor
    test "a recipient should exist", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn = get(conn, "/n/api/v1/recipient?email=#{nu.email}")
      assert response(conn, 200)

      r = json_response(conn, 200)
      assert r["exists"] == true
      assert r["id"] == nr.id
    end

    @tag :requestor
    test "a recipient can be updated, no email change", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        put(conn, "/n/api/v1/recipient/#{nr.id}", %{
          "name" => "NEWNAME",
          "organization" => nr.organization,
          "email" => nu.email,
          "phone_number" => nr.phone_number,
          "start_date" => nr.start_date,
          "tags" => []
        })

      assert response(conn, 200)

      nr = Repo.get(Recipient, nr.id)
      assert nr.name == "NEWNAME"
    end

    @tag :requestor
    test "recipient tag update", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)

      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        put(conn, "/n/api/v1/recipient/#{nr.id}", %{
          "name" => "NEWNAME",
          "organization" => nr.organization,
          "email" => nu.email,
          "phone_number" => nr.phone_number,
          "start_date" => nr.start_date,
          "tags" => [1,2,3]
        })

      assert response(conn, 200)

      nr = Repo.get(Recipient, nr.id)
      assert nr.name == "NEWNAME"
      assert nr.tags == [1,2,3]
    end

    ###
    ### Access Control Checks
    ###

    @tag :recipient
    test "access: recipient cannot change a recipient", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      company = Repo.get(Company, us_user.company_id)
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})

      conn =
        put(conn, "/n/api/v1/recipient/#{nr.id}", %{
          "name" => "NEWNAME",
          "organization" => nr.organization,
          "email" => nu.email,
          "phone_number" => nr.phone_number,
          "start_date" => nr.start_date
        })

      assert response(conn, 403)
    end

    @tag :recipient
    test "access: recipients shouldnt be able to query others", %{conn: conn} do
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
      conn = get(conn, "/n/api/v1/recipient?email=#{us_user.email}")
      assert response(conn, 403)
    end

    @tag :recipient
    test "access: recipients cannot delete other recipients", %{conn: conn} do
      conn = delete(conn, "/n/api/v1/recipient/1")

      assert response(conn, 403)
    end

    @tag :recipient
    test "access: recipient-by-id  have no access", %{conn: conn} do
      conn = get(conn, "/n/api/v1/recipient/1")

      assert response(conn, 403)
    end

    @tag :recipient
    test "access: recipients have no access", %{conn: conn} do
      conn = get(conn, "/n/api/v1/recipients")

      assert response(conn, 403)
    end

    @tag :recipient
    test "access: recipients cannot create a recipient", %{conn: conn} do
      conn =
        post(conn, "/n/api/v1/recipient", %{
          "organization" => "NEWORG",
          "name" => "NEWCONTACT",
          "email" => "new_contact@cetlie.hu",
          "phone_number" => "+15552121234",
          "start_date" => nil
        })

      assert response(conn, 403)
    end
  end
end
