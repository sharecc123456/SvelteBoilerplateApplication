defmodule BoilerplateWeb.FormControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory
  alias BoilerPlateWeb.FormController
  alias BoilerPlate.Repo
  alias BoilerPlate.PackageAssignment
  alias BoilerPlate.Form
  alias BoilerPlate.FormSubmission
  alias BoilerPlate.FormField

  ###
  ### Helpers
  ###

  def form_verify_field(actual_field, expected_field, struct: false) do
    assert expected_field["title"] == actual_field["title"]
    assert expected_field["label"] == actual_field["label"]
    assert expected_field["description"] == actual_field["description"]
    assert expected_field["options"] == actual_field["options"]
    assert expected_field["required"] == actual_field["required"]
    assert expected_field["is_multiple"] == actual_field["is_multiple"]
    assert expected_field["is_numeric"] == actual_field["is_numeric"]
    assert expected_field["type"] == actual_field["type"]
  end

  def form_verify_field(actual_field, expected_field, struct: true) do
    assert expected_field.title == actual_field["title"]
    assert expected_field.label == actual_field["label"]
    assert expected_field.description == actual_field["description"]
    assert expected_field.options == actual_field["options"]
    assert expected_field.required == actual_field["required"]
    assert expected_field.is_multiple == actual_field["is_multiple"]
    assert expected_field.is_numeric == actual_field["is_numeric"]
    assert expected_field.type == actual_field["type"]
  end

  def form_verify_fields(actual, expected) do
    assert length(actual) == length(expected)

    for actual_field <- actual do
      # find matching order field
      expected_field = Enum.find(expected, fn x -> x["order_id"] == actual_field["order_id"] end)

      form_verify_field(actual_field, expected_field, struct: false)
    end
  end

  def form_verify(actual, expected) do
    assert actual["title"] == expected["title"]
    assert actual["description"] == expected["description"]
    assert actual["has_repeat_entries"] == expected["has_repeat_entries"]
    assert actual["has_repeat_vertical"] == expected["has_repeat_vertical"]
    assert actual["repeat_label"] == expected["repeat_label"]

    form_verify_fields(actual["formFields"], expected["formFields"])
  end

  ###
  ### Actual Tests
  ###

  describe "Form API" do
    @form_input %{
      "title" => "Form",
      "description" => "Form desc",
      "formFields" => [
        %{
          "title" => "Enter Name",
          "label" => "",
          "description" => "",
          "options" => [],
          "required" => true,
          "is_multiple" => false,
          "is_numeric" => false,
          "order_id" => 0,
          "type" => "shortAnswer"
        },
        %{
          "title" => "Enter age",
          "label" => "",
          "description" => "",
          "options" => [],
          "required" => true,
          "is_multiple" => false,
          "is_numeric" => true,
          "order_id" => 1,
          "type" => "number"
        }
      ],
      "has_repeat_entries" => false,
      "has_repeat_vertical" => false,
      "repeat_label" => ""
    }
    @tag :requestor
    test "can create and read form", %{conn: conn} do
      form = FormController.create_form(@form_input)
      conn = get(conn, "/n/api/v1/form/#{form.id}")
      json = json_response(conn, 200)

      form_verify(json, @form_input)
    end

    @tag :requestor
    test "Create with form with Factory", %{conn: conn} do
      form = insert(:form)
      af1 = insert(:form_field, %{form_id: form.id})
      af2 = insert(:form_field, %{form_id: form.id, is_numeric: true})

      conn = get(conn, "/n/api/v1/form/#{form.id}")
      json = json_response(conn, 200)
      assert json_response(conn, 200)
      assert json["id"] == form.id
      assert json["title"] == form.title
      assert json["description"] == form.description
      assert length(json["formFields"]) == 2

      [f1, f2] = json["formFields"]

      form_verify_field(f1, af1, struct: true)
      form_verify_field(f2, af2, struct: true)
    end

    @tag :requestor
    test "Send Assignment with Form", %{
      conn: conn,
      requestor_company: company,
      requestor: requestor
    } do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      form = insert(:form, %{package_id: pkg.id})
      af1 = insert(:form_field, %{form_id: form.id})
      af2 = insert(:form_field, %{form_id: form.id, is_numeric: true})

      contents = insert_contents(conn, nr, pkg, struct: false)
      [cf] = contents["forms"]
      assert cf["id"] != form.id
      assert cf["title"] == form.title
      assert cf["description"] == form.description
      assert Enum.count(cf["formFields"]) == 2

      [f1, f2] = cf["formFields"]
      form_verify_field(f1, af1, struct: true)
      form_verify_field(f2, af2, struct: true)

      conn =
        post(conn, "/n/api/v1/assignment", %{
          "enforceDueDate" => false,
          "dueDays" => 1,
          "contentsId" => contents["id"],
          "append_note" => "appendNote",
          "checklistIdentifier" => "test"
        })

      assert text_response(conn, 200) =~ "OK"
      assert Repo.aggregate(PackageAssignment, :count) == 1

      asmt = Repo.one(PackageAssignment)
      assert asmt.contents_id == contents["id"]
      assert asmt.company_id == company.id
      assert asmt.recipient_id == nr.id
      assert asmt.requestor_id == requestor.id

      conn = post(conn, "/n/api/v1/dashboard/#{nr.id}")
      rasmts = json_response(conn, 200)
      checklists = rasmts["checklists"]
      [cl] = checklists

      dashboard_verify_checklist(cl, asmt, nr)
    end

    @tag :requestor
    test "Unsend form", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      nr = insert(:recipient, %{company_id: company.id, user_id: nu.id})
      f1 = insert(:form, %{package_id: pkg.id})
      insert(:form_field, %{form_id: f1.id})
      insert(:form_field, %{form_id: f1.id, is_numeric: true})
      f2 = insert(:form, %{package_id: pkg.id})
      insert(:form_field, %{form_id: f2.id})
      insert(:form_field, %{form_id: f2.id, is_numeric: true})

      conn =
        post(conn, "/n/api/v1/contents", %{
          "packageId" => pkg.id,
          "recipientId" => nr.id
        })

      contents_id = json_response(conn, 200)["id"]
      conn = get(conn, "/n/api/v1/contents/#{nr.id}/#{pkg.id}")
      assert json_response(conn, 200)

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
      forms = cl["forms"]
      assert Enum.count(forms) == 2

      # unsend form
      [f1, f2] = forms
      asmt_id = cl["id"]
      f_id = f1["id"]
      conn = post(conn, "/n/api/v1/form/unsend/#{asmt_id}/#{f_id}")
      json = json_response(conn, 200)
      assert json
      assert json["message"] == "updated"
      assert json["form_id"] == f_id

      # check form was removed
      conn = post(conn, "/n/api/v1/dashboard/#{nr.id}")
      rasmts = json_response(conn, 200)
      checklists = rasmts["checklists"]
      [cl] = checklists
      forms = cl["forms"]

      assert Enum.count(forms) == 1
      [f] = forms
      assert f["id"] == f2["id"]
    end

    @tag :requestor
    test "Create Form Submission", %{conn: conn, requestor_company: company} do
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
      assert json_response(conn, 200)

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
      assert Enum.count(cl["forms"]) == 1
      [rf] = cl["forms"]
      [f1, f2] = rf["formFields"]

      conn = switch_to_user(nu, type: :recipient)

      f1_id = f1["id"]
      f2_id = f2["id"]

      # create form_submission
      submission = %{
        "form_values" => %{
          "#{f1_id}" => "Akashdeep",
          "#{f2_id}" => 25
        },
        "form_id" => rf["id"],
        "assignment_id" => cl["id"]
      }

      conn = post(conn, "/n/api/v1/form-submission", submission)
      json = json_response(conn, 200)
      assert json["msg"] == "inserted"
      fs_id = json["id"]
      fs = Repo.get(FormSubmission, fs_id)
      form_values = fs.form_values
      assert form_values["#{f1_id}"] == "Akashdeep"
      assert form_values["#{f2_id}"] == 25
    end

    @tag :requestor
    test "Get Form Submission", %{conn: conn, requestor_company: company} do
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
      assert json_response(conn, 200)

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
      assert Enum.count(cl["forms"]) == 1
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
      json = json_response(conn, 200)
      assert json["msg"] == "inserted"
      assert json["id"] != 0
      fs_id = json["id"]

      conn = get(conn, "/n/api/v1/form-submission/#{asmt_id}/#{f_id}")
      json = json_response(conn, 200)
      assert length(json["formFields"]) == 2

      f1_check =
        Enum.find_value(json["formFields"], fn x ->
          if x["id"] == f1_id do
            x
          else
            nil
          end
        end)

      f2_check =
        Enum.find_value(json["formFields"], fn x ->
          if x["id"] == f2_id do
            x
          else
            nil
          end
        end)

      assert f1_check != nil
      assert f2_check != nil
      assert f1_check["value"] == "Akashdeep"
      assert f2_check["value"] == 25
      assert json["submission_id"] == fs_id
      assert json["id"] == f_id
    end

    @tag :requestor
    test "Create form for contents", %{conn: conn, requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      nu = insert(:user, %{company_id: company.id})
      insert(:recipient, %{company_id: company.id, user_id: nu.id})
      form = insert(:form, %{package_id: pkg.id})
      insert(:form_field, %{form_id: form.id})
      insert(:form_field, %{form_id: form.id, is_numeric: true})

      conn = get(conn, "/n/api/v1/form/#{form.id}")
      af = json_response(conn, 200)

      conn = post(conn, "/n/api/v1/form", af |> Map.put("checklist_id", pkg.id))
      ef = json_response(conn, 200)

      form_verify(af, ef)
    end

    @tag :requestor
    test "can delete form submission", %{conn: conn, requestor_company: company} do
      fs_id = insert_form_submission(conn, company)
      conn = delete(conn, "/n/api/v1/form-submission", %{"form_submission_id" => fs_id})
      json = json_response(conn, 200)
      assert json["id"] == fs_id
      assert json["msg"] == "deleted"
      ef = Repo.get(FormSubmission, json["id"])
      assert ef.status == 4
    end

    ################
    ## unit tests ##
    ################
    @tag :requestor
    test "can update form", %{conn: conn} do
      f = insert(:form, %{package_id: 0})
      insert(:form_field, %{form_id: f.id})

      conn = get(conn, "/n/api/v1/form/#{f.id}")
      f = json_response(conn, 200)

      # update form data
      ff = f["formFields"]
      [ff1] = ff
      af1 = ff1 |> Map.put("is_numeric", true)

      af =
        f
        |> Map.put("title", "New form title")
        |> Map.put("description", "New form desc")
        |> Map.put("formFields", [af1])

      f_id = FormController.update_form(af)

      conn = get(conn, "/n/api/v1/form/#{f_id}")
      ef = json_response(conn, 200)
      form_verify(af, ef)
    end

    test "can delete form" do
      f = insert(:form, %{package_id: 0})
      ff = insert(:form_field, %{form_id: f.id})

      FormController.delete_form(f.id)
      ef = Repo.get(Form, f.id)
      eff = Repo.get(FormField, ff.id)

      assert ef.status == 1
      assert eff.status == 1
    end

    test "can search form" do
      f1 = insert(:form, %{package_id: 0})
      insert(:form_field, %{form_id: f1.id})
      f2 = insert(:form, %{package_id: 0})
      insert(:form_field, %{form_id: f2.id, label: "name"})

      ef1 = FormController.get_form_with_fields(f1.id)
      ef2 = FormController.get_form_with_fields(f2.id)

      sf = [ef1, ef2]
      found = FormController.findInForms?(sf, "esc")
      assert found
      found = FormController.findInForms?(sf, "orm")
      assert found
      found = FormController.findInForms?(sf, "eld")
      assert found
      found = FormController.findInForms?(sf, "ame")
      assert found
    end

    @tag :requestor
    test "can accept form submission", %{
      conn: conn,
      requestor: requestor,
      requestor_company: company
    } do
      fs_id = insert_form_submission(conn, company)
      res = FormController.accept_form_submission(requestor, fs_id)
      assert res == :ok
    end

    @tag :requestor
    test "can reject form submission", %{
      conn: conn,
      requestor_user: user,
      requestor_company: company
    } do
      fs_id = insert_form_submission(conn, company)

      params = %{
        "form_submission_id" => fs_id,
        "return_comments" => "I don't like it"
      }

      res = FormController.return_form_submission(user, params)
      assert res == :ok
    end
  end
end
