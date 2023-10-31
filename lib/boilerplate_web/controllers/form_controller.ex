alias BoilerPlate.Repo
alias BoilerPlate.Helpers
alias BoilerPlate.Company
alias BoilerPlate.Recipient
alias BoilerPlate.Package
alias BoilerPlate.PackageContents
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Form
alias BoilerPlate.FormField
alias BoilerPlate.FormSubmission
alias BoilerPlate.Helpers
alias BoilerPlate.IACField
import Ecto.Query
require Logger

defmodule BoilerPlateWeb.FormController do
  use BoilerPlateWeb, :controller

  def create_form_for_contents(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    package_id = params["checklist_id"]
    package = Repo.get(Package, package_id)
    company = Repo.get(Company, package.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      # because this is an orphan it belongs to package contents forms[]
      new_params = params |> Map.put("checklist_id", 0)
      {form, form_fields} = create_form(new_params, has_master: false, get_map: false)
      render(conn, "form.json", form: form, fields: form_fields)
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  @create_form_opts [has_master: false, get_map: true]
  def create_form(params, opts \\ []) do
    # return form_id
    title = params["title"]
    has_repeat_entries = params["has_repeat_entries"] || false
    has_repeat_vertical = params["has_repeat_vertical"] || false
    repeat_label = params["repeat_label"] || ""
    description = params["description"]
    form_fields = params["formFields"]
    package_id = params["checklist_id"] || 0
    repeat_entry_default_value = params["repeat_entry_default_value"] || %{}

    %{has_master: has_master, get_map: get_map} =
      Keyword.merge(@create_form_opts, opts) |> Enum.into(%{})

    new_form = %{
      title: title,
      description: description,
      package_id: package_id,
      has_repeat_entries: has_repeat_entries,
      has_repeat_vertical: has_repeat_vertical,
      repeat_entry_default_value: repeat_entry_default_value,
      repeat_label: repeat_label,
      master_form_id:
        if has_master do
          params["id"]
        else
          nil
        end
    }

    cs = Form.changeset(%Form{}, new_form)

    form_inserted = Repo.insert!(cs)

    form_id = form_inserted.id

    if get_map do
      form_fields
      |> Enum.each(fn new_form_field ->
        create_form_field(new_form_field, form_id)
      end)

      get_form_with_fields(form_id)
    else
      {form_inserted,
       form_fields
       |> Enum.map(fn new_form_field ->
         create_form_field(new_form_field, form_id, get_id: false)
       end)}
    end
  end

  def delete_form(id) do
    form = Repo.get(Form, id)
    form_data = get_form_with_fields(id)
    form_cs = Form.changeset(form, %{status: 1})

    Repo.update!(form_cs)

    form_data.formFields
    |> Enum.each(fn field ->
      field.id |> delete_form_field
    end)

    id
  end

  def delete_form_field(id) do
    form_field = Repo.get(FormField, id)
    field_cs = FormField.changeset(form_field, %{status: 1})

    Repo.update!(field_cs)
    id
  end

  # internal function for creating form field
  @create_form_fields_opts [get_id: true]
  def create_form_field(form_field, form_id, opts \\ []) do
    %{get_id: get_id} = Keyword.merge(@create_form_fields_opts, opts) |> Enum.into(%{})

    cs_input = %FormField{
      form_id: form_id,
      title: form_field["title"],
      label: form_field["label"] || "",
      description: form_field["description"] || "",
      options: form_field["options"],
      required: form_field["required"],
      type: form_field["type"],
      is_multiple: form_field["is_multiple"],
      is_numeric: form_field["is_numeric"],
      order_id: form_field["order_id"],
      default_value: form_field["default_value"] || %{}
    }

    form_field_inserted = Repo.insert!(cs_input)

    if get_id do
      form_field_inserted.id
    else
      form_field_inserted
    end
  end

  # public function a adding a form submission
  def create_form_submission(conn, params) do
    # get user and check if he is assigned the contents then only allow submission
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    assignment_id = params["assignment_id"]
    assignment = Repo.get(PackageAssignment, assignment_id)

    recipient =
      Repo.get_by(Recipient, %{status: 0, user_id: us_user.id, company_id: assignment.company_id})

    company = Repo.get(Company, recipient.company_id)

    if BoilerPlate.AccessPolicy.has_access_to?(:company, company, us_user) do
      contents_id = assignment.contents_id
      form_id = params["form_id"]
      form_values = params["form_values"]

      last_form_submission = get_last_form_submission(form_id, contents_id)

      if last_form_submission == nil or last_form_submission.status == 3 do
        form_submission_cs = %FormSubmission{
          contents_id: contents_id,
          form_id: form_id,
          form_values: form_values,
          status: 1
        }

        form_submission = Repo.insert!(form_submission_cs)

        # send emails for completed checklists
        package = Repo.get(Package, assignment.package_id)
        contents = Repo.get(PackageContents, contents_id)

        if package != nil do
          if Package.check_if_completed_by(assignment, recipient) do
            Logger.info("Form submission: Checklist Completed ....")

            BoilerPlateWeb.UserController.send_package_completed_email(
              contents,
              assignment.requestor_id,
              recipient
            )
          end
        end

        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
        conn |> json(%{id: form_submission.id, msg: "inserted"})
      else
        if last_form_submission.status == 2 do
          conn |> put_status(400) |> text("Bad Request, submission already accepted")
        else
          submission_changes = %{
            form_values: form_values,
            status: 1
          }

          last_form_submission
          |> update_form_submission(submission_changes)

          conn |> json(%{id: last_form_submission.id, msg: "updated"})
        end
      end
    else
      conn |> put_status(403) |> text("Forbidden")
    end

    # create new submission only in one case case:
    # no exisiting submssions with status: 0, status: 3 for reject, status: 2 for accept
  end

  def update_form_submission(form_submission, submission_changes) do
    Repo.update!(FormSubmission.changeset(form_submission, submission_changes))
  end

  def accept_form_submission(requestor, form_submission_id) do
    form_submission = Repo.get(FormSubmission, form_submission_id)
    contents_id = form_submission.contents_id

    assignment =
      Repo.one(
        from pa in PackageAssignment,
          where: pa.contents_id == ^contents_id,
          select: pa
      )

    company = Repo.get(Company, assignment.company_id)

    # %{id: form_submission_id, msg: "accepted"}
    if requestor != nil and requestor.company_id == company.id do
      form_submission
      |> update_form_submission(%{status: 2})

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
      :ok
    else
      :forbidden
    end
  end

  def return_form_submission(us_user, params) do
    # check if the requestor is owner of the assignment
    form_submission_id = params["form_submission_id"]
    return_comments = params["return_comments"] || ""

    form_submission = Repo.get(FormSubmission, form_submission_id)
    contents_id = form_submission.contents_id

    assignment =
      Repo.one(
        from pa in PackageAssignment,
          where: pa.contents_id == ^contents_id,
          select: pa
      )

    company = Repo.get(Company, assignment.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      submission_changes = %{
        status: 3,
        return_comments: return_comments
      }

      form_submission
      |> update_form_submission(submission_changes)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
      :ok
    else
      :forbidden
    end
  end

  def handle_delete_form_submission(conn, params) do
    form_submission_id = params["form_submission_id"]
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    form_submission = Repo.get(FormSubmission, form_submission_id)
    contents_id = form_submission.contents_id

    assignment =
      Repo.one(
        from pa in PackageAssignment,
          where: pa.contents_id == ^contents_id,
          select: pa
      )

    company = Repo.get(Company, assignment.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      # for manual delete status = 4
      delete_form_submission(form_submission_id, 4)
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)

      conn |> json(%{id: form_submission_id, msg: "deleted"})
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  # for manual delete status = 4
  # for auto delete status = 9
  def delete_form_submission(id, status) do
    form_submission = Repo.get(FormSubmission, id)

    if form_submission.status == 4 or form_submission.status == 9 do
      %{
        id: id,
        msg: "already deleted"
      }
    else
      submission_changes = %{
        status: status
      }

      form_submission
      |> update_form_submission(submission_changes)

      %{
        id: id,
        msg: "deleted"
      }
    end
  end

  def get_last_form_submission(form_id, contents_id) do
    Repo.one(
      from fs in FormSubmission,
        where: fs.contents_id == ^contents_id and fs.form_id == ^form_id,
        order_by: [desc: fs.inserted_at],
        limit: 1,
        select: fs
    )
  end

  def get_form_submission_map(fs) do
    if fs == nil do
      fs
    else
      %{
        id: fs.id,
        contents_id: fs.contents_id,
        form_id: fs.form_id,
        status: fs.status,
        form_values: fs.form_values,
        return_comments: fs.return_comments,
        inserted_at: fs.inserted_at,
        updated_at: fs.updated_at
      }
    end
  end

  def get_form_field_map(ff) do
    if ff == nil do
      ff
    else
      %{
        id: ff.id,
        title: ff.title,
        label: ff.label,
        description: ff.description,
        type: ff.type,
        is_multiple: ff.is_multiple,
        is_numeric: ff.is_numeric,
        options: ff.options,
        required: ff.required,
        order_id: ff.order_id,
        default_value: ff.default_value
      }
    end
  end

  # case 1: while assigning to a package_content, we just need company_form_ids
  # case 2: while sending data to client/admin for preview

  def get_content_forms(conn, params) do
    package_id = params["package_id"]

    ids = package_id |> get_company_form_ids_for_contents

    conn |> json(%{ids: ids})
  end

  def get_company_form_ids_for_contents(package_id) do
    package_id
    |> duplicate_forms
    |> Enum.map(fn form -> form.id end)
  end

  def duplicate_forms(old_package_id, new_package_id \\ 0) do
    # get the forms from package
    forms = get_forms_for_package(old_package_id)
    # create the new forms for the package/contents
    # incase of contents, new_package_id = 0
    forms
    |> Enum.map(fn form ->
      fields =
        form.formFields
        |> Enum.map(fn f ->
          f |> Helpers.atom_keys_to_string()
        end)

      form_input =
        form
        |> Helpers.atom_keys_to_string()
        |> Map.put("formFields", fields)
        |> Map.put("checklist_id", new_package_id)

      form_input
      |> create_form(has_master: true)
    end)
  end

  def duplicate_form_with_id_map(form_id, package_id) do
    old_form = Repo.get(Form, form_id)
    fields = get_form_fields(form_id, get_map: false)

    new_form =
      Repo.insert!(%Form{
        title: old_form.title,
        description: old_form.description,
        package_id: package_id,
        has_repeat_entries: old_form.has_repeat_entries,
        has_repeat_vertical: old_form.has_repeat_vertical,
        repeat_label: old_form.repeat_label,
        master_form_id: old_form.id
      })

    field_map =
      for field <- fields, into: %{} do
        new_field =
          Repo.insert!(%FormField{
            title: field.title,
            label: field.label,
            description: field.description,
            type: field.type,
            required: field.required,
            options: field.options,
            form_id: new_form.id,
            is_numeric: field.is_numeric,
            is_multiple: field.is_multiple,
            order_id: field.order_id,
            status: field.status,
            default_value: field.default_value
          })

        {field.id, new_field.id}
      end

    {new_form, field_map}
  end

  def get_form_for_api(form_id) do
    form = Repo.get(Form, form_id)
    form_map = get_form_map(form)
    form_fields = get_form_fields(form.id, get_map: true)

    Map.put(form_map, :formFields, form_fields)
  end

  def get_forms_for_package(package_id) do
    forms =
      Repo.all(
        from f in Form,
          where: f.package_id == ^package_id and f.status != 1,
          select: f
      )
      |> Enum.map(fn f -> get_form_map(f) end)

    forms
    |> Enum.map(fn form ->
      form_fields = get_form_fields(form.id, get_map: true)
      form |> Map.put(:formFields, form_fields)
    end)
  end

  def update_form(updated_form_data, incoming_form_id \\ 0) do
    form_id = updated_form_data["id"] || incoming_form_id
    form = Repo.get(Form, form_id)

    form_cs =
      Form.changeset(form, %{
        title: updated_form_data["title"],
        description: updated_form_data["description"],
        has_repeat_entries: updated_form_data["has_repeat_entries"],
        has_repeat_vertical: updated_form_data["has_repeat_vertical"],
        repeat_label: updated_form_data["repeat_label"]
      })

    if form_cs.changes |> Enum.count() > 0 do
      Repo.update!(form_cs)
    end

    # add/update form fields
    new_form_fields = updated_form_data["formFields"]

    new_field_ids =
      new_form_fields
      |> Enum.map(fn field ->
        if field["id"] == nil do
          create_form_field(field, form_id, get_id: true)
        else
          update_form_field(field, form_id, get_id: true)
        end
      end)

    # delete removed form fields
    old_fields = get_form_fields(form_id, get_map: false)

    old_fields
    |> Enum.each(fn old_field ->
      id = old_field.id

      if id not in new_field_ids do
        id |> delete_form_field
      end
    end)

    form_id
  end

  # TODO(nandi): check if the field is part of the form
  @update_form_field_opts [get_id: true]
  def update_form_field(updated_field, _form_id, opts \\ []) do
    field_id = updated_field["id"]
    cs_data = updated_field |> Map.new(fn {k, v} -> {String.to_atom(k), v} end) |> Map.delete(:id)
    form_field = Repo.get(FormField, field_id)
    field_cs = FormField.changeset(form_field, cs_data)
    %{get_id: get_id} = Keyword.merge(@update_form_field_opts, opts) |> Enum.into(%{})

    new_field =
      if field_cs.changes |> Enum.count() > 0 do
        Repo.update!(field_cs)
      end

    if get_id do
      field_id
    else
      new_field
    end
  end

  def add_forms_in_package(new_forms, package_id) do
    package_forms = get_forms(package_id, false)

    # add/update forms
    new_company_form_ids =
      new_forms
      |> Enum.map(fn new_form ->
        if new_form["id"] == nil do
          # got the created form
          saved_form =
            new_form
            |> Map.put("checklist_id", package_id)
            |> create_form

          saved_form.id
        else
          update_form(new_form)
        end
      end)

    # delete removed forms
    package_forms
    |> Enum.each(fn old_form ->
      form_id = old_form.id

      if form_id not in new_company_form_ids do
        form_id |> delete_form
      end
    end)
  end

  def get_submission_state(form_submission, assignment) do
    cond do
      form_submission == nil ->
        %{
          # new
          status: 0,
          date: assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: assignment.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }

      form_submission.status == 1 ->
        %{
          # Submitted for review
          status: 2,
          date: form_submission.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: form_submission.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }

      form_submission.status == 2 ->
        %{
          # Completed
          status: 4,
          date: form_submission.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: form_submission.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }

      form_submission.status == 3 ->
        %{
          # returned
          status: 3,
          date: form_submission.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: form_submission.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }

      form_submission.status == 9 ->
        %{
          # auto deleted
          status: 9,
          date: form_submission.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: form_submission.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }

      form_submission.status == 4 ->
        %{
          # manually deleted
          status: 10,
          date: form_submission.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: form_submission.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
        }
    end
  end

  def get_forms_for_contents(contents_id, for_review \\ false, recipient_submitted \\ false) do
    contents = Repo.get(PackageContents, contents_id)

    if contents.forms != nil do
      forms =
        contents.forms
        |> Enum.map(fn id ->
          id |> get_form_submission(contents_id)
        end)

      if for_review do
        # check status as well
        forms |> Enum.filter(&(&1.is_submitted && &1.status == 1))
      else
        if recipient_submitted do
          forms |> Enum.filter(&(&1.is_submitted))
        else
          forms
        end
      end
    else
      []
    end
  end

  @get_form_fields_opts [get_map: true]
  def get_form_fields(form_id, opts \\ []) do
    %{get_map: get_map} = Keyword.merge(@get_form_fields_opts, opts) |> Enum.into(%{})

    fields =
      Repo.all(
        from ff in FormField,
          where: ff.form_id == ^form_id and ff.status != 1,
          order_by: [asc: ff.order_id],
          select: ff
      )

    if get_map do
      fields |> Enum.map(fn field -> get_form_field_map(field) end)
    else
      fields
    end
  end

  def get_form_with_fields(form_id) do
    form =
      Repo.one(
        from f in Form,
          where: f.id == ^form_id and f.status != 1,
          select: %{
            id: f.id,
            title: f.title,
            description: f.description,
            has_repeat_entries: f.has_repeat_entries,
            has_repeat_vertical: f.has_repeat_vertical,
            repeat_entry_default_value: f.repeat_entry_default_value,
            repeat_label: f.repeat_label,
            # to be changed by form submission
            status: 0
          }
      )

    form_fields = get_form_fields(form_id, get_map: true)

    %{
      id: form.id,
      title: form.title,
      description: form.description,
      has_repeat_entries: form.has_repeat_entries,
      has_repeat_vertical: form.has_repeat_vertical,
      repeat_entry_default_value: form.repeat_entry_default_value,
      repeat_label: form.repeat_label,
      formFields: form_fields
    }
  end

  def parse_numeric_field(field_value, is_multiple) do
    if is_multiple do
      field_value
      |> Enum.map(fn val ->
        val |> Helpers.parse_number()
      end)
    else
      field_value |> Helpers.parse_number()
    end
  end

  def get_form_submission(form_id, contents_id) do
    assignment =
      Repo.one(
        from a in PackageAssignment,
          where: a.contents_id == ^contents_id,
          select: a
      )

    form = get_form_with_fields(form_id)

    form_submission =
      form_id
      |> get_last_form_submission(contents_id)
      |> get_form_submission_map

    if form_submission == nil do
      form_fields =
        form.formFields
        |> Enum.map(fn field ->
          if field.is_multiple do
            if Map.has_key?(field.default_value, "value") do
              field |> Map.put(:values, field.default_value["value"])
            else
              field |> Map.put(:values, [])
            end
          else
            if Map.has_key?(field.default_value, "value") do
              field |> Map.put(:value, field.default_value["value"])
            else
              field |> Map.put(:value, "")
            end
          end
        end)

      submission =
        form
        |> Map.delete(:form_fields)
        |> Map.put(:formFields, form_fields)
        |> Map.put(:entries, [])

      submission =
        if form.repeat_entry_default_value != nil and
             Map.has_key?(form.repeat_entry_default_value, "entries") do
          submission |> Map.put(:entries, form.repeat_entry_default_value)
        else
          submission |> Map.put(:entries, [])
        end

      if assignment == nil do
        submission
      else
        submission
        |> Map.put(:state, get_submission_state(nil, assignment))
        |> Map.put(:is_submitted, false)
        |> Map.put(:submission_id, 0)
        |> Map.put(:status, 0)
        |> Map.put(
          :submitted,
          assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}")
        )
      end
    else
      form_values = form_submission.form_values
      has_repeat_entries = form.has_repeat_entries
      form_fields = form.formFields

      form_fields =
        if has_repeat_entries do
          form_fields
        else
          form_fields
          |> Enum.map(fn field ->
            field_value = form_values[to_string(field.id)]
            is_numeric = field.is_numeric
            is_multiple = field.is_multiple

            parsed_value =
              cond do
                field_value == nil and is_multiple -> []
                field_value == nil -> nil
                is_numeric == true -> field_value |> parse_numeric_field(is_multiple)
                true -> field_value
              end

            key = if is_multiple, do: :values, else: :value

            field |> Map.put(key, parsed_value)
          end)
        end

      submission =
        form
        |> Map.delete(:form_fields)
        |> Map.put(:formFields, form_fields)
        |> Map.put(:status, form_submission.status)
        |> Map.put(:submission_id, form_submission.id)
        |> Map.put(:return_comments, form_submission.return_comments)
        |> Map.put(:is_submitted, true)
        |> Map.put(
          :submitted,
          form_submission.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}")
        )

      submission =
        if has_repeat_entries do
          entries = form_values["entries"] || []
          submission |> Map.put(:entries, entries)
        else
          submission
        end

      if assignment == nil do
        submission
      else
        submission |> Map.put(:state, get_submission_state(form_submission, assignment))
      end
    end
  end

  def get_form_map(f) do
    if f == nil do
      f
    else
      %{
        id: f.id,
        title: f.title,
        description: f.description,
        has_repeat_entries: f.has_repeat_entries,
        has_repeat_vertical: f.has_repeat_vertical,
        repeat_entry_default_value: f.repeat_entry_default_value,
        repeat_label: f.repeat_label
      }
    end
  end

  def get_forms(package_id, get_map \\ true) do
    forms =
      Repo.all(
        from f in Form,
          where: f.package_id == ^package_id and f.status != 1,
          select: f
      )

    if get_map do
      forms |> Enum.map(fn form -> get_form_map(form) end)
    else
      forms
    end
  end

  def handle_get_form_submission(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment_id = params["assignment_id"]
    assignment = Repo.get(PackageAssignment, assignment_id)
    company = Repo.get(Company, assignment.company_id)
    contents_id = assignment.contents_id
    form_id = params["form_id"]

    recipient = Repo.get_by(Recipient, %{user_id: us_user.id, status: 0, company_id: company.id})

    has_access =
      BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) or
        (recipient != nil and assignment.recipient_id == recipient.id)

    # condition for checking the access
    if has_access do
      form_submission = form_id |> get_form_submission(contents_id)
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
      conn |> json(form_submission)
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def search_form(form, search_keyword) do
    Helpers.stringContains?(form.title, search_keyword) ||
      Helpers.stringContains?(form.description, search_keyword) ||
      form.formFields
      |> Enum.any?(fn field ->
        Helpers.stringContains?(field.title, search_keyword) ||
          Helpers.stringContains?(field.label, search_keyword)
      end)
  end

  def findInForms?(forms, search_keyword) do
    forms |> Enum.any?(fn form -> form |> search_form(search_keyword) end)
  end

  def unsend_form(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment_id = params["assignment_id"]
    assignment = Repo.get(PackageAssignment, assignment_id)
    company = Repo.get(Company, assignment.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      contents_id = assignment.contents_id
      {form_id, _} = Integer.parse(params["form_id"])

      contents = Repo.get(PackageContents, contents_id)

      new_forms =
        contents.forms
        |> Enum.filter(&(&1 != form_id))

      contents_cs = PackageContents.changeset(contents, %{forms: new_forms})

      Repo.update!(contents_cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, contents.recipient_id)

      conn |> json(%{message: "updated", form_id: form_id})
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  # Update the default_value for each form_field
  def prefill_form_for_contents(conn, %{"form_id" => form_id, "formFields" => fields}) do
    requestor = get_current_requestor(conn)
    form = Repo.get(Form, form_id)

    # TODO security: check if the form is part of this company
    if requestor == nil or form == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      for incoming_field <- fields do
        ff = Repo.get(FormField, incoming_field["id"])

        if ff != nil and ff.form_id == form.id do
          val = %{value: incoming_field["default_value"]}
          Repo.update!(FormField.changeset(ff, %{default_value: val}))
        end
      end

      text(conn, "OK")
    end
  end

  def iac_attach_form(conn, %{"field_id" => iac_field_id, "form" => incoming_form}) do
    requestor = get_current_requestor(conn)
    iacfield = Repo.get(IACField, iac_field_id)

    # TODO SECURITY: check if the field belongs to this company
    if requestor == nil or iacfield == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      form_map = create_form(incoming_form, has_master: false)
      form_id = form_map.id
      Repo.update!(IACField.changeset(iacfield, %{repeat_entry_form_id: form_id}))
      json(conn, %{status: :ok, form_id: form_id})
    end
  end

  def iac_update_attached_form(conn, %{"field_id" => iac_field_id, "form" => incoming_form}) do
    requestor = get_current_requestor(conn)
    iacfield = Repo.get(IACField, iac_field_id)

    # TODO SECURITY: check if the field belongs to this company
    if requestor == nil or iacfield == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      update_form(incoming_form, iacfield.repeat_entry_form_id)
      json(conn, %{status: :ok})
    end
  end

  def get_form_by_id(conn, %{"form_id" => form_id}) do
    requestor = get_current_requestor(conn)
    form = Repo.get(Form, form_id)

    if requestor == nil or form == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      render(conn, "form.json", form: form, fields: get_form_fields(form_id, get_map: false))
    end
  end

  def get_forms_assigned_by_company(company_id) do
    Repo.all(
      from pc in PackageContents,
        join: assign in PackageAssignment,
        on: assign.contents_id == pc.id,
        where: assign.company_id == ^company_id and fragment("? <> '{}'", pc.forms),
        select: pc.forms
    )
    |> List.flatten()
  end

  def get_processed_forms_for_company(company_id, start_time_period, end_time_period) do
    company_form_ids = get_forms_assigned_by_company(company_id)

    query =
      from form_submmision in BoilerPlate.FormSubmission,
        where:
          form_submmision.form_id in ^company_form_ids and
            form_submmision.inserted_at >= ^start_time_period and
            form_submmision.inserted_at <= ^end_time_period

    Repo.aggregate(query, :count, :id)
  end

  def get_total_questions_answered_for_company(company_id, start_time_period, end_time_period) do
    company_form_ids = get_forms_assigned_by_company(company_id)

    query =
      from form_submmision in BoilerPlate.FormSubmission,
        where:
          form_submmision.form_id in ^company_form_ids and
            form_submmision.inserted_at >= ^start_time_period and
            form_submmision.inserted_at <= ^end_time_period and
            fragment("? <> '{}'", form_submmision.form_values),
        select: form_submmision.form_values

    Repo.all(query) |> Enum.reduce(0, fn x, acc -> acc + Enum.count(x) end)
  end
end
