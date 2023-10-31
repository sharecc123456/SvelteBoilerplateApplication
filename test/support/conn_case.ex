defmodule BoilerPlateWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate
  require Logger
  import BoilerPlate.Factory

  @default_opts [
    store: :cookie,
    key: "_boilerplate_test_key",
    signing_salt: "534j6h3456kj3h56"
  ]
  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      alias BoilerPlateWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BoilerPlateWeb.Endpoint

      def expect_forbidden_get(path, conn) do
        conn = get(conn, path)
        assert response(conn, 403)
      end

      def expect_forbidden_post(path, data, conn) do
        conn = post(conn, path, data)
        assert response(conn, 403)
      end

      def switch_to_user(user, opts \\ []) do
        type = Keyword.get(opts, :type, :recipient)

        case type do
          :recipient ->
            Phoenix.ConnTest.build_conn()
            |> Plug.Session.call(
              Plug.Session.init(
                store: :cookie,
                key: "_boilerplate_test_key",
                signing_salt: "534j6h3456kj3h56",
                encrypt: false
              )
            )
            |> Plug.Conn.fetch_session()
            |> BoilerPlate.Guardian.Plug.sign_in(user, %{
              two_factor_approved: true
            })

            :requestor

            Phoenix.ConnTest.build_conn()
            |> Plug.Session.call(
              Plug.Session.init(
                store: :cookie,
                key: "_boilerplate_test_key",
                signing_salt: "534j6h3456kj3h56",
                encrypt: false
              )
            )
            |> Plug.Conn.fetch_session()
            |> BoilerPlate.Guardian.Plug.sign_in(user, %{
              two_factor_approved: true,
              blptreq: true
            })
        end
      end

      @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"
      @insert_iac_setup_default [with_labels: false]
      def insert_iac_setup(us_user, company, options \\ []) do
        options = Keyword.merge(@insert_iac_setup_default, options) |> Enum.into(%{})
        %{with_labels: with_labels} = options
        iac_fn = build(:upload, file_name: @sample_iac_pdf, iac: true)

        rd =
          insert(:raw_document, %{
            file_name: iac_fn,
            company_id: company.id,
            flags: 2
          })

        iac_doc =
          insert(:iac_document, %{
            document_type: BoilerPlate.IACDocument.document_type(:raw_document),
            document_id: rd.id,
            file_name: iac_fn
          })

        iacmfid =
          File.read!("#{@sample_iac_pdf}.iac.json")
          |> Jason.decode!()
          |> BoilerPlateWeb.IACController.import_iac(iac_doc, us_user)

        iac_doc = BoilerPlate.Repo.get(BoilerPlate.IACDocument, iac_doc.id)

        if with_labels do
          for field <- BoilerPlate.IACMasterForm.raw_fields_of(iac_doc) do
            BoilerPlate.Repo.update!(
              BoilerPlate.IACField.changeset(field, %{
                label: build(:iac_label).value
              })
            )
          end
        end

        {iac_doc, iacmfid}
      end

      def insert_iac_fill(us_user, company, recipient, options \\ []) do
        with {iac_doc, iacmfid} <- insert_iac_setup(us_user, company, options) do

          pkg = insert(:packages, %{company_id: company.id})
          dr = insert(:document_request, %{packageid: 0})
          pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: recipient.id, requests: [dr.id], documents: [iac_doc.document_id]})

          na = insert(:package_assignments, %{
            recipient_id: recipient.id,
            contents_id: pc.id,
            package_id: pkg.id,
            company_id: company.id
          })

          new_iac_doc=
            BoilerPlate.Repo.update!(
                BoilerPlate.IACDocument.changeset(iac_doc, %{
                  document_type: BoilerPlate.IACDocument.document_type(:raw_document_customized),
                  raw_document_id: iac_doc.document_id,
                  contents_id: pc.id,
                  recipient_id: recipient.id,
                  status: 0,
                  flags: 0
                })
              )

          iacmf = BoilerPlate.Repo.get(BoilerPlate.IACMasterForm, iacmfid)

          iacaf =
            insert(:iac_assigned_form, %{
              company_id: company.id,
              contents_id: pc.id,
              master_form_id: iacmfid,
              recipient_id: recipient.id,
              fields: iacmf.fields,
              status: 0
            })

          rdc =
            insert(:raw_document_customized, %{
              contents_id: new_iac_doc.contents_id,
              file_name: new_iac_doc.file_name,
              recipient_id: new_iac_doc.recipient_id,
              raw_document_id: new_iac_doc.raw_document_id,
              flags: 0,
              status: 0
            })

          final_iac_doc =
            BoilerPlate.Repo.update!(
                BoilerPlate.IACDocument.changeset(new_iac_doc, %{
                  document_id: rdc.id,
                })
              )
          {final_iac_doc, iacmfid, rdc, na, iacaf}
        end
      end

      def insert_contents(conn, recipient, pkg),
        do: _insert_contents(conn, recipient, pkg, struct: true)

      def insert_contents(conn, recipient, pkg, struct: s),
        do: _insert_contents(conn, recipient, pkg, struct: s)

      defp _insert_contents(conn, recipient, pkg, struct: s) do
        conn =
          post(conn, "/n/api/v1/contents", %{
            "packageId" => pkg.id,
            "recipientId" => recipient.id
          })

        assert json_response(conn, 200)
        contents_id = json_response(conn, 200)["id"]

        if s do
          BoilerPlate.Repo.get(BoilerPlate.PackageContents, contents_id)
        else
          json_response(conn, 200)
        end
      end

      def commit_contents(contents, conn) do
        conn =
          post(conn, "/n/api/v1/contents/#{contents.id}/commit", %{
            "documentIds" =>
              contents.documents
              |> Enum.map(&BoilerPlate.Repo.get(BoilerPlate.RawDocument, &1))
              |> Enum.filter(&BoilerPlate.RawDocument.is_rspec?/1)
              |> Enum.map(& &1.id)
          })

        assert text_response(conn, 200) =~ "OK"

        contents
      end

      def assign_it(contents, conn) do
        conn =
          post(conn, "/n/api/v1/assignment", %{
            "enforceDueDate" => false,
            "dueDays" => 1,
            "contentsId" => contents.id,
            "append_note" => "appendNote",
            "checklistIdentifier" => "test"
          })

        assert text_response(conn, 200) =~ "OK"

        {BoilerPlate.Repo.get_by(BoilerPlate.PackageAssignment, %{contents_id: contents.id}),
         contents}
      end

      def verify_dashboard({ass, _}, conn), do: verify_dashboard(conn, [ass])

      def verify_dashboard(conn, assignments) when is_list(assignments) do
        for ass <- assignments do
          verify_dashboard_assignment(conn, ass)
        end
      end

      def verify_dashboard(conn, assignment), do: verify_dashboard(conn, [assignment])

      def verify_dashboard_assignment(conn, ass) do
        assert ass != nil
        recp = BoilerPlate.Repo.get(BoilerPlate.Recipient, ass.recipient_id)
        assert recp != nil
        recp_user = BoilerPlate.Repo.get(BoilerPlate.User, recp.user_id)
        assert recp_user != nil

        conn = post(conn, "/n/api/v1/metadashboard")
        assert json_response(conn, 200)
        data = json_response(conn, 200)["data"]
        assert length(data) >= 1

        first =
          Enum.find_value(data, fn x ->
            if x["recipient"]["id"] == recp.id do
              x
            else
              nil
            end
          end)

        assert first != nil

        # check that the recipient is correct
        recipient_on_dashboard = first["recipient"]
        assert recipient_on_dashboard["name"] == recp.name
        assert recipient_on_dashboard["email"] == recp_user.email

        checklists = first["checklists"]
        assert length(checklists) >= 1

        # Now verify the checklist
        the_checklist =
          Enum.find_value(checklists, fn x ->
            if x["id"] == ass.id do
              x
            else
              nil
            end
          end)

        assert the_checklist != nil
        dashboard_verify_checklist(the_checklist, ass, recp)
      end

      def dashboard_verify_checklist(cl, ass, recp) do
        contents = BoilerPlate.Repo.get(BoilerPlate.PackageContents, ass.contents_id)

        assert cl["package_id"] == ass.package_id
        assert cl["recipient_id"] == recp.id
        assert cl["id"] == ass.id

        assert length(cl["tags"]) != nil
        assert Enum.map(cl["tags"], &(&1["id"])) == contents.tags

        if is_list(cl["document_requests"]) do
          assert length(cl["document_requests"]) == length(contents.documents)

          for dr <- cl["document_requests"] do
            assert Enum.member?(contents.documents, dr["id"])
            rd = BoilerPlate.Repo.get(BoilerPlate.RawDocument, dr["id"])
            assert rd != nil
            assert dr["description"] == rd.description
            assert dr["id"] == rd.id
            assert dr["name"] == rd.name
            assert dr["is_rspec"] == BoilerPlate.RawDocument.is_rspec?(rd)
          end
        else
          assert contents.documents == []
        end

        if is_list(cl["file_requests"]) do
          assert length(cl["file_requests"]) == length(contents.requests)

          for fr <- cl["file_requests"] do
            assert Enum.member?(contents.requests, fr["id"])
            req = BoilerPlate.Repo.get(BoilerPlate.DocumentRequest, fr["id"])
            assert req.title == fr["name"]
            assert req.description == fr["description"]
          end
        else
          assert contents.requests == []
        end

        if is_list(cl["forms"]) do
          assert length(cl["forms"]) == length(contents.forms)

          for form <- cl["forms"] do
            actual_form = BoilerPlate.Repo.get(BoilerPlate.Form, form["id"])

            assert actual_form.title == form["title"]
            assert actual_form.description == form["description"]
            assert actual_form.has_repeat_entries == form["has_repeat_entries"]
            assert actual_form.has_repeat_vertical == form["has_repeat_vertical"]
            assert actual_form.repeat_label == form["repeat_label"]

            fields = BoilerPlateWeb.FormController.get_form_fields(form["id"], get_map: false)
            assert length(fields) == length(form["formFields"])

            for actual_field <- form["formFields"] do
              expected_field = BoilerPlate.Repo.get(BoilerPlate.FormField, actual_field["id"])
              assert expected_field.title == actual_field["title"]
              assert expected_field.label == actual_field["label"]
              assert expected_field.description == actual_field["description"]
              assert expected_field.options == actual_field["options"]
              assert expected_field.required == actual_field["required"]
              assert expected_field.is_multiple == actual_field["is_multiple"]
              assert expected_field.is_numeric == actual_field["is_numeric"]
              assert expected_field.type == actual_field["type"]
            end
          end
        else
          assert contents.forms == []
        end
      end

      def insert_form_submission(conn, company) do
        pkg = insert(:packages, %{company_id: company.id})
        nu = insert(:user, %{company_id: company.id})
        nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
        form = insert(:form, %{package_id: pkg.id})
        insert(:form_field, %{form_id: form.id})
        insert(:form_field, %{form_id: form.id, is_numeric: true})

        conn =
          post(conn, "/n/api/v1/contents", %{
            "packageId" => pkg.id,
            "recipientId" => nr.id
          })

        contents_id = json_response(conn, 200)["id"]
        conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")

        conn =
          post(conn, "/n/api/v1/assignment", %{
            "enforceDueDate" => false,
            "dueDays" => 1,
            "contentsId" => contents_id,
            "append_note" => "appendNote",
            "checklistIdentifier" => "test"
          })

        conn = post(conn, "/n/api/v1/dashboard/#{nr.id}")
        rasmts = json_response(conn, 200)
        checklists = rasmts["checklists"]
        [cl] = checklists
        [rf] = cl["forms"]
        [f1, f2] = rf["formFields"]

        # change to recipient now
        conn = switch_to_user(nu, type: :recipient)

        f1_id = f1["id"]
        f2_id = f2["id"]
        f_id = rf["id"]
        asmt_id = cl["id"]

        # create form_submission
        submission = %{
          "form_values" => %{
            "#{f1_id}" => "Akashdeep",
            "#{f2_id}" => 25
          },
          "form_id" => f_id,
          "assignment_id" => asmt_id
        }

        conn = post(conn, "/n/api/v1/form-submission", submission)
        json_response(conn, 200)["id"]
      end
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(BoilerPlate.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    conn = Phoenix.ConnTest.build_conn()

    {conn, requestor_user, requestor, requestor_company} =
      if tags[:requestor] do
        admin_company = insert(:company)
        admin_user = insert(:user, %{company_id: admin_company.id})

        admin_requestor =
          insert(:requestor, %{
            company_id: admin_company.id,
            user_id: admin_user.id,
            name: admin_user.name,
            organization: admin_user.organization
          })

        Logger.info(
          "Running with requestor #{admin_requestor.id} user #{admin_user.id} company #{admin_company.id}"
        )

        conn =
          conn
          |> Plug.Session.call(@signing_opts)
          |> Plug.Conn.fetch_session()
          |> BoilerPlate.Guardian.Plug.sign_in(admin_user, %{
            two_factor_approved: true,
            blptreq: true
          })

        {conn, admin_user, admin_requestor, admin_company}
      else
        {conn, nil, nil, nil}
      end

    {conn, admin_user, admin_requestor, admin_company} =
      if tags[:instance_admin] do
        admin_company = insert(:company, %{status: 2, flags: 4})
        admin_user = insert(:user, %{company_id: admin_company.id, email: "lk@cetlie.hu"})

        admin_requestor =
          insert(:requestor, %{
            company_id: admin_company.id,
            user_id: admin_user.id,
            name: admin_user.name,
            organization: admin_user.organization
          })

        Logger.info(
          "Running with admin requestor #{admin_requestor.id} user #{admin_user.id} company #{admin_company.id}"
        )

        conn =
          conn
          |> Plug.Session.call(@signing_opts)
          |> Plug.Conn.fetch_session()
          |> BoilerPlate.Guardian.Plug.sign_in(admin_user, %{
            two_factor_approved: true,
            blptreq: true
          })

        {conn, admin_user, admin_requestor, admin_company}
      else
        {conn, nil, nil, nil}
      end

    {conn, recipient_user, recipient, recipient_company} =
      if tags[:recipient] do
        admin_company = insert(:company)
        admin_user = insert(:user, %{company_id: admin_company.id})

        admin_recipient =
          insert(:recipient, %{
            user_id: admin_user.id,
            company_id: admin_company.id,
            name: admin_user.name,
            organization: admin_company.name
          })

        Logger.info(
          "Running with recipient #{admin_recipient.id} user #{admin_user.id} company #{admin_company.id}"
        )

        conn =
          conn
          |> Plug.Session.call(@signing_opts)
          |> Plug.Conn.fetch_session()
          |> BoilerPlate.Guardian.Plug.sign_in(admin_user, %{
            two_factor_approved: true,
            blptreq: false
          })

        {conn, admin_user, admin_recipient, admin_company}
      else
        {conn, nil, nil, nil}
      end

    %{
      conn: conn,
      recipient_user: recipient_user,
      recipient_company: recipient_company,
      recipient: recipient,
      requestor_user: requestor_user,
      requestor_company: requestor_company,
      requestor: requestor,
      admin_requestor: admin_requestor,
      admin_company: admin_company,
      admin_user: admin_user
    }
  end
end
