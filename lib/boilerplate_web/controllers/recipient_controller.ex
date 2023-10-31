alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.Helpers
alias BoilerPlate.Company
alias BoilerPlate.Package
alias BoilerPlate.RawDocument
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACField
alias BoilerPlate.Recipient
alias BoilerPlate.RecipientData
alias BoilerPlate.Requestor
alias BoilerPlate.PackageContents
alias BoilerPlate.PackageAssignment
alias BoilerPlate.FormSubmission
alias BoilerPlate.FormField
alias BoilerPlate.Form
alias BoilerPlate.Helpers
import BoilerPlate.AuditLog
import Ecto.Query
require Logger

defmodule DataTabData do
  @enforce_keys [:id, :label, :type, :source, :updated, :value]
  defstruct id: 0,
            label: "",
            type: "",
            source: %{type: "", origin: "", origin_id: 0},
            updated: "",
            value: ""
end

defmodule DataTabSource do
  @enforce_keys [:type, :origin, :origin_id]
  defstruct [:type, :origin, :origin_id]
end

defmodule BoilerPlateWeb.RecipientController do
  use BoilerPlateWeb, :controller

  ###
  ### API
  ###

  defp email_exists?(company, email) do
    query =
      from u in User,
        join: r in Recipient,
        on: r.user_id == u.id,
        where:
          u.email == ^email and
            r.status == 0 and
            r.company_id == ^company.id,
        select: u

    Repo.aggregate(query, :count, :id) > 0
  end

  defp invitation_ok?(name, email, _org, company) do
    email = String.trim(String.downcase(email))

    cond do
      name == nil || name == "" ||
        email == nil || email == "" ->
        :missing_info

      email_exists?(company, email) ->
        :email_in_use

      true ->
        :ok
    end
  end

  # We shouldn't be able to change an email:
  #  - If the recipient is part of multiple companies
  #  - If the recipient is also a requestor
  #  - If the recipient has already logged in
  def recipient_email_editable(recp) do
    us = Repo.get(User, recp.user_id)
    company_query = from c in Recipient, where: c.user_id == ^us.id and c.status == 0, select: c
    requestor_query = from r in Requestor, where: r.user_id == ^us.id and r.status == 0, select: r
    company_count = Repo.aggregate(company_query, :count, :id)
    requestor_count = Repo.aggregate(requestor_query, :count, :id)

    # logins_count starts with 1 for some reason
    us.logins_count < 2 and company_count == 1 and requestor_count == 0
  end

  defp resend_assignments_emails_of(us_user, recipient) do
    recp_user = Repo.get(User, recipient.user_id)

    assignments =
      Repo.all(
        from pa in PackageAssignment,
          where: pa.recipient_id == ^recipient.id and pa.status == 0,
          select: pa
      )

    for ass <- assignments do
      package = Repo.get(PackageContents, ass.contents_id)
      company = Repo.get(Company, recipient.company_id)

      BoilerPlate.Email.send_assigned_email(
        recp_user,
        recipient,
        package,
        company,
        us_user,
        ass,
        ass.append_note
      )
    end
  end

  @spec apply_label_filter([RecipientData.api()], String.t()) :: [RecipientData.api()]
  defp apply_label_filter(data, label) do
    if label == nil do
      data
    else
      Enum.filter(data, &(&1.label == label))
    end
  end

  # Fetch data tab contents from the recipient's form submissions.
  # Options:
  # - `label` => set to a string if you only want data for a given label, if nil, returns all data.
  @spec get_data_from_forms(Recipient.t(),
          label: String.t() | nil,
          form_submission_id: integer,
          contents_id: integer
        ) :: [RecipientData.api()]
  defp get_data_from_forms(recipient, options) do
    defaults = [label: nil, form_submission_id: nil, contents_id: nil]
    options = Keyword.merge(defaults, options) |> Enum.into(%{})

    %{label: only_this_label, form_submission_id: form_submission_id, contents_id: contents_id} =
      options

    new_label_start_date = ~D[2022-09-11]

    form_submission_condition =
      cond do
        form_submission_id == nil and contents_id == nil ->
          dynamic(
            [pc, fs],
            pc.recipient_id == ^recipient.id and
              fragment("?::date", fs.inserted_at) >= ^new_label_start_date
          )

        form_submission_id != nil ->
          dynamic(
            [pc, fs],
            pc.recipient_id == ^recipient.id and fs.id == ^form_submission_id and
              fragment("?::date", fs.inserted_at) >= ^new_label_start_date
          )

        #
        contents_id != nil ->
          dynamic(
            [pc, fs],
            pc.recipient_id == ^recipient.id and pc.id == ^contents_id and
              fragment("?::date", fs.inserted_at) >= ^new_label_start_date
          )

        true ->
          raise ArgumentError, message: "invalid filter state in get_data_from_forms"
      end

    subq =
      from pc in PackageContents,
        join: fs in FormSubmission,
        on: pc.id == fs.contents_id,
        where: ^form_submission_condition,
        select: fs.form_id

    labels =
      Repo.all(
        from ff in FormField,
          where: ff.form_id in subquery(subq) and ff.label != "" and not is_nil(ff.label),
          select: %{id: ff.id, label: ff.label}
      )
      |> Map.new(fn x -> {x.id, x.label} end)

    form_subq =
      from pc in PackageContents,
        join: fs in FormSubmission,
        on: pc.id == fs.contents_id,
        where: ^form_submission_condition,
        select: fs.form_id

    form_values =
      Repo.all(
        from fs in FormSubmission,
          where: fs.status != 3 and fs.form_id in subquery(form_subq),
          order_by: [desc: fs.inserted_at],
          select: %{id: fs.id, form_id: fs.form_id, values: fs.form_values}
      )
      |> Enum.map(fn x ->
        if Map.has_key?(x.values, "entries") do
          %{type: :repeat, form_id: x.form_id, submission_id: x.id, entries: x.values["entries"]}
        else
          %{type: :normal, data: Map.to_list(x.values)}
        end
      end)

    # TODO(lev/9189): Eek. This stinks.
    for fv <- form_values do
      if fv.type == :normal do
        for {fvk, val} <- fv.data do
          # XXX(lev): this is really slow
          ff = Repo.get(FormField, fvk)
          fff = Repo.get(Form, ff.form_id)

          %DataTabData{
            id: 0,
            label: labels[String.to_integer(fvk)],
            type: ff.type,
            source: %DataTabSource{type: "form_data", origin: fff.title, origin_id: fff.id},
            updated: ff.updated_at,
            value:
              if ff.type == "radio" and not is_list(val) do
                [val]
              else
                val
              end
          }
        end
      else
        f = Repo.get(Form, fv.form_id)
        fs = Repo.get(FormSubmission, fv.submission_id)

        real_values =
          fv.entries
          |> Enum.map(fn single_entry ->
            for {k, v} <- Map.to_list(single_entry), into: %{} do
              seff = Repo.get(FormField, k)
              {seff.title, %{type: seff.type, value: v, sort_order: seff.order_id}}
            end
          end)

        [
          %DataTabData{
            id: 0,
            label: f.repeat_label,
            type: "repeat",
            source: %DataTabSource{
              type: "form_data_repeat",
              origin: f.title,
              origin_id: f.id
            },
            updated: fs.updated_at,
            value: real_values
          }
        ]
      end
    end
    |> Enum.concat()
    |> apply_label_filter(only_this_label)
  end

  defp get_data_from_data(recipient, options \\ []) do
    defaults = [label: nil]
    options = Keyword.merge(defaults, options) |> Enum.into(%{})
    %{label: only_this_label} = options

    conditions =
      if only_this_label == nil do
        dynamic([rd], rd.recipient_id == ^recipient.id and rd.status == 0)
      else
        dynamic(
          [rd],
          rd.recipient_id == ^recipient.id and rd.label == ^only_this_label
        )
      end

    Repo.all(
      from rd in RecipientData,
        where: ^conditions,
        select: rd
    )
    |> Enum.map(fn rd ->
      if Map.has_key?(rd.value, "value") do
        %DataTabData{
          id: 0,
          label: rd.label,
          # XXX: Eww.
          type:
            if is_list(rd.value["value"]) do
              "checkbox"
            else
              "shortAnswer"
            end,
          source: %DataTabSource{
            type: "profile",
            origin: "manual",
            origin_id: rd.id
          },
          updated: rd.inserted_at,
          value: rd.value["value"]
        }
      else
        # Repeat Entry Profile Data
        %DataTabData{
          id: 0,
          label: rd.label,
          # XXX
          type: "repeat",
          source: %DataTabSource{
            type: "form_data_repeat",
            origin: rd.value["form_title"] || "Manual Input",
            origin_id: rd.value["form_id"] || 0
          },
          updated: rd.inserted_at,
          value:
            rd.value["repeat_value"]
            |> Enum.map(fn v ->
              for v2 <- v, into: %{} do
                {v2["name"],
                 %{
                   fieldId: v2["fieldId"],
                   label: v2["label"],
                   type: "shortAnswer",
                   value: v2["value"]
                 }}
              end
            end)
        }
      end
    end)
  end

  defp populate_contacts_data_with_labels(recipient) do
    recipient_email = Repo.get(User, recipient.user_id).email
    recipient_info = Map.merge(recipient, %{email: recipient_email})
    labels = Recipient.get_data_to_map()

    labels
    |> Enum.map(fn label ->
      if label == "start_date" do
        data = Map.fetch(recipient_info, String.to_atom(label)) |> elem(1)

        data =
          if data == nil do
            ""
          else
            case Timex.format(data, "{YYYY}-{0M}-{0D}") do
              {:ok, val} -> val
              {:error, _term} -> ""
            end
          end

        %DataTabData{
          id: 0,
          label: Recipient.get_recipient_spec_label(label),
          type: "shortAnswer",
          source: %DataTabSource{
            type: "pseudo_profile",
            origin: "contact details",
            origin_id: recipient.id
          },
          updated: recipient_info.updated_at,
          value: data
        }
      else
        %DataTabData{
          id: 0,
          label: Recipient.get_recipient_spec_label(label),
          type: "shortAnswer",
          source: %DataTabSource{
            type: "pseudo_profile",
            origin: "contact details",
            origin_id: recipient.id
          },
          updated: recipient_info.updated_at,
          value: Map.fetch(recipient_info, String.to_atom(label)) |> elem(1)
        }
      end
    end)
    |> Enum.filter(&(&1.value != ""))
  end

  ###
  ### API Calls
  ###

  @doc """
    Get the history of a given label pertaining to a recipient.
  """
  def api_requestor_recipient_data_label_history(recipient, label) do
    data_from_forms = get_data_from_forms(recipient, label: label)
    data_from_recipient_data = get_data_from_data(recipient, label: label)

    proton =
      Enum.sort_by(
        data_from_recipient_data ++ data_from_forms,
        & &1.updated,
        {:desc, NaiveDateTime}
      )

    IO.inspect(proton)

    for {id, d} <- Enum.with_index(proton, fn e, i -> {i, e} end) do
      Map.put(d, :id, id)
    end
  end

  def api_requestor_recipient_data(recipient, options \\ []) do
    defaults = [form_submission_id: nil, contents_id: nil]
    options = Keyword.merge(defaults, options) |> Enum.into(%{})
    %{form_submission_id: form_submission_id, contents_id: contents_id} = options

    data_from_forms =
      get_data_from_forms(recipient,
        form_submission_id: form_submission_id,
        contents_id: contents_id
      )
      |> Enum.uniq_by(& &1.label)

    data_from_recipient_data =
      if form_submission_id == nil and contents_id == nil do
        get_data_from_data(recipient)
      else
        []
      end

    proton =
      Enum.sort_by(
        data_from_recipient_data ++ data_from_forms,
        & &1.updated,
        {:desc, NaiveDateTime}
      )
      |> Enum.uniq_by(& &1.label)

    for {id, d} <- Enum.with_index(proton, fn e, i -> {i, e} end) do
      Map.put(d, :id, id)
    end
  end

  def requestor_recipient_data_for_rsd_template(recipient) do
    profile_labels = api_requestor_recipient_data(recipient)
    contact_details_labels = populate_contacts_data_with_labels(recipient)

    # the list merge order is Very important here since contact detail label has highest precedence
    protons = contact_details_labels ++ profile_labels

    # Enum.uniq_by: Two elements are considered duplicates if the return value of fun is equal for both of them.
    # The first occurrence of each element is kept
    protons |> Enum.uniq_by(& &1.label)
  end

  @spec api_requestor_new_recipient_data(%Requestor{}, Recipient.t(), String.t(), map) :: :ok
  def api_requestor_new_recipient_data(_requestor, recipient, label, value) do
    # Check if this label already exists in a recipientData
    rd = Repo.get_by(RecipientData, %{recipient_id: recipient.id, label: label, status: 0})

    if rd == nil do
      Repo.insert!(%RecipientData{
        status: 0,
        flags: 0,
        recipient_id: recipient.id,
        label: label,
        value: value
      })
    else
      # retire the old recipientdata
      Repo.update!(RecipientData.changeset(rd, %{status: 1}))

      Repo.insert!(%RecipientData{
        status: 0,
        flags: 0,
        recipient_id: recipient.id,
        label: label,
        value: value
      })
    end

    :ok
  end

  def api_requestor_recipient_data_make_form(_recipient, templates) do
    if length(templates) != 1 do
      {:err, "Currently we only support a single template export."}
    else
      iac_fields =
        templates
        |> Enum.map(fn x -> IACDocument.get_for(:raw_document, Repo.get(RawDocument, x)) end)
        |> Enum.flat_map(fn iac_doc -> IACMasterForm.fields_of(iac_doc) end)

      label_data =
        iac_fields
        |> Enum.filter(fn x ->
          x.label != nil and x.label != "" and x.label_question != nil and x.label_question != ""
        end)
        |> Enum.sort(IACField)
        |> Enum.group_by(fn x -> x.label end)

      repeat_entry_forms =
        iac_fields
        |> Enum.filter(
          &(&1.field_type == 4 and &1.repeat_entry_form_id != nil and &1.repeat_entry_form_id != 0)
        )
        |> Enum.map(&BoilerPlateWeb.FormController.get_form_for_api(&1.repeat_entry_form_id))

      {_, fields} =
        for {label, proto} <- label_data do
          proto_len = length(proto)
          IO.inspect(label, label: "label")
          IO.inspect(proto, label: "proto")

          cond do
            proto_len == 1 ->
              p = Enum.at(proto, 0)

              %{
                id: 0,
                title: p.label_question,
                label: p.label,
                description: "",
                type: p.label_question_type,
                is_multiple: false,
                is_numeric: p.label_question_type == "number",
                internal: %{
                  location_data: IACField.make_location_spec(p)
                },
                options: [],
                required: false,
                value: "",
                order_id: 0
              }

            proto_len > 1 ->
              values = Enum.map(proto, & &1.label_value)
              p = Enum.at(proto, 0)

              %{
                id: 0,
                title: p.label_question,
                label: p.label,
                description: "",
                type: p.label_question_type,
                is_multiple: p.label_question_type == "checkbox",
                values: [],
                value: "",
                internal: %{
                  location_data: IACField.make_location_spec(p)
                },
                is_numeric: false,
                options: values,
                required: false,
                order_id: 0
              }

            true ->
              raise ArgumentError, message: "bad proto_len"
          end
        end
        |> Enum.sort(fn f, s ->
          fl = f.internal.location_data
          sl = s.internal.location_data
          res = IACField.compare_location_specs(fl, sl)

          res == :eq or res == :lt
        end)
        |> Enum.reduce({0, []}, fn x, {i, arr} ->
          {i + 1, arr ++ [Map.put(x, :id, i) |> Map.put(:order_id, i)]}
        end)

      {:ok, fields, repeat_entry_forms}
    end
  end

  @spec api_requestor_recipient_data_put_form_repeat(%Requestor{}, Recipient.t(), [any]) :: :ok
  def api_requestor_recipient_data_put_form_repeat(requestor, recipient, data) do
    label = data["repeat_label"]
    form_title = data["form_title"] || "Manual Input"
    form_id = data["form_id"] || 0

    api_requestor_new_recipient_data(requestor, recipient, label, %{
      form_title: form_title,
      form_id: form_id,
      repeat_value: data["data"]
    })

    :ok
  end

  @spec api_requestor_recipient_data_put_form(%Requestor{}, Recipient.t(), [any]) :: :ok
  def api_requestor_recipient_data_put_form(requestor, recipient, data) do
    for d <- data do
      label = d["label"]
      value = d["value"]

      api_requestor_new_recipient_data(requestor, recipient, label, %{value: value})
    end

    :ok
  end

  def api_requestor_recipient_data_verify_form(requestor, recipient, raw_forms, template_name) do
    checklist_name = "Data Verification - #{template_name}"
    checklist_description = "Verify your data"

    checklist =
      Repo.insert!(%Package{
        templates: [],
        title: checklist_name,
        description: checklist_description,
        company_id: requestor.company_id,
        status: 0,
        allow_duplicate_submission: false,
        allow_multiple_requests: false,
        is_archived: true,
        enforce_due_date: false,
        due_date_type: nil,
        due_days: nil
      })

    # Create the checklist
    IO.inspect(raw_forms, label: "raw_forms")

    form_ids =
      Enum.map(raw_forms, fn raw_form ->
        if raw_form["has_repeat_entries"] do
          # create a copy from whatever is in the DB, get back a id->id map
          # where the left handside is the master id and the right handside is
          # the new field that corresponds to the master field
          {new_form, field_map} =
            BoilerPlateWeb.FormController.duplicate_form_with_id_map(raw_form["id"], checklist.id)

          # Now go through all entries in the raw_form
          entries = raw_form["entries"]
          IO.inspect(entries, label: "entries_for_repeat_#{raw_form["id"]}")

          mapped_entries =
            if entries == nil do
              []
            else
              for entry <- entries do
                for {key, value} <- entry, into: %{} do
                  {field_map[String.to_integer(key)], value}
                end
              end
            end

          Repo.update!(
            Form.changeset(new_form, %{repeat_entry_default_value: %{entries: mapped_entries}})
          )

          new_form.id
        else
          # create this form immediately
          form = BoilerPlateWeb.FormController.create_form(raw_form, has_master: false)
          form_struct = Repo.get(Form, form.id)
          Repo.update!(Form.changeset(form_struct, %{package_id: checklist.id}))
          profile_data = api_requestor_recipient_data(recipient)

          form_fields = BoilerPlateWeb.FormController.get_form_fields(form.id, get_map: false)
          # Go through the fields and set default values depending on the profile-level data
          for f_field <- form_fields do
            if f_field.label != nil and f_field.label != "" do
              # it has a label - check if the profile data has it
              value =
                Enum.find_value(profile_data, fn e ->
                  if e.label == f_field.label and e.value != nil and e.value != false do
                    e.value
                  end
                end)

              if value != nil do
                # Found a value!
                Repo.update!(FormField.changeset(f_field, %{default_value: %{value: value}}))
              end
            end
          end

          # use the labels to prefill this form as per normal
          form.id
        end
      end)

    # Create a contents from it, THIS IS WASTEFUL>>revise this code!!!!!
    contents = PackageContents.inprogress_package(recipient, checklist)
    Repo.update!(PackageContents.changeset(contents, %{forms: form_ids}))
    {:ok, checklist.id}
  end

  defp api_edit_recipient(us_user, uid, org, name, email, phone_number, start_date, tags) do
    recipient = Repo.get(Recipient, uid)
    company = Repo.get(Company, recipient.company_id)
    current_recp_user = Repo.get(User, recipient.user_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      email_update_response =
        if current_recp_user.email != email do
          Logger.info("EMAIL CHANGE DETECTED")
          # Email change requested
          if recipient_email_editable(recipient) do
            # change email
            cs = User.changeset(current_recp_user, %{email: email})
            Repo.update!(cs)

            # resend assignments
            resend_assignments_emails_of(us_user, recipient)

            {:ok, true}
          else
            {:error, :non_editable}
          end
        else
          {:ok, false}
        end

      case email_update_response do
        {:ok, changed?} ->
          audit(:recipient_edit, %{
            user: us_user,
            company_id: company.id,
            recipient_name: recipient.name,
            recipient_id: recipient.id,
            new_name: name,
            new_org: org,
            recipient_org: recipient.organization,
            user_id: recipient.user_id,
            phone_number: recipient.phone_number,
            new_phone_number: phone_number
          })

          cs =
            Recipient.changeset(recipient, %{
              name: name,
              organization: org,
              phone_number: phone_number,
              start_date: Helpers.get_utc_date(start_date),
              tags: tags
            })

          Repo.update!(cs)

          BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

          {:ok,
           if changed? do
             :email_changed
           else
             :no_email_change
           end}

        r ->
          r
      end
    else
      audit(:recipient_edit, %{
        user: us_user,
        company_id: company.id,
        recipient_name: recipient.name,
        recipient_id: recipient.id,
        new_name: name,
        new_org: org,
        recipient_org: recipient.organization,
        user_id: recipient.user_id,
        phone_number: recipient.phone_number,
        new_phone_number: phone_number,
        reason: 2
      })

      {:error, :forbidden}
    end
  end

  ###
  ### Plug calls
  ###

  def requestor_recipient_data_verify_form(conn, %{
        "id" => recipient_id,
        "forms" => forms,
        "templateName" => template_name
      }) do
    requestor = get_current_requestor(conn)
    recipient = Repo.get(Recipient, recipient_id)

    if requestor == nil or recipient == nil or
         requestor.company_id != recipient.company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      case api_requestor_recipient_data_verify_form(requestor, recipient, forms, template_name) do
        {:ok, checklist_id} -> json(conn, %{checklistId: checklist_id})
      end
    end
  end

  def requestor_new_recipient_data(conn, %{
        "id" => rid,
        "label" => label,
        "value" => value
      }) do
    requestor = get_current_requestor(conn)
    recipient = Repo.get(Recipient, rid)

    if requestor == nil or recipient.company_id != requestor.company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      case api_requestor_new_recipient_data(requestor, recipient, label, %{value: value}) do
        :ok -> conn |> text("OK")
      end
    end
  end

  def requestor_recipient_data_make_form(conn, %{"id" => rid, "templates" => templates}) do
    requestor = get_current_requestor(conn)
    recipient = Repo.get(Recipient, rid)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("Forbidden")

      recipient == nil ->
        conn |> put_status(404) |> text("No recipient")

      requestor.company_id != recipient.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      Enum.empty?(templates) ->
        conn |> put_status(400) |> text("No templates")

      true ->
        case api_requestor_recipient_data_make_form(recipient, templates) do
          {:ok, form_data, repeat_entry_forms} ->
            json(conn, %{basic_form: form_data, repeat_entry_forms: repeat_entry_forms})

          {:err, msg} ->
            conn |> put_status(400) |> text(msg)
        end
    end
  end

  def requestor_recipient_data_put_form(conn, params = %{"id" => rid}) do
    requestor = get_current_requestor(conn)
    recipient = Repo.get(Recipient, rid)
    data = params["data"] || false
    repeat_data = params["repeat_data"] || false

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("Forbidden")

      recipient == nil ->
        conn |> put_status(404) |> text("No recipient")

      requestor.company_id != recipient.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      data != false ->
        case api_requestor_recipient_data_put_form(requestor, recipient, data) do
          :ok ->
            text(conn, "OK")
        end

      repeat_data != false ->
        case api_requestor_recipient_data_put_form_repeat(requestor, recipient, repeat_data) do
          :ok ->
            text(conn, "OK")
        end

      true ->
        conn |> put_status(400) |> text("no repeat_data and no data")
    end
  end

  def requestor_recipient_data(conn, %{"id" => rid}) do
    recipient = Repo.get(Recipient, rid)
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("Forbidden")

      recipient == nil ->
        conn |> put_status(404) |> text("Not Found")

      requestor.company_id != recipient.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        render(conn, "data_tab.json", data_tab: api_requestor_recipient_data(recipient))
    end
  end

  def requestor_recipient_label_history(conn, %{"id" => rid, "label" => label}) do
    recipient = Repo.get(Recipient, rid)
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("Forbidden")

      recipient == nil ->
        conn |> put_status(404) |> text("Not Found")

      requestor.company_id != recipient.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        render(conn, "data_tab.json",
          data_tab: api_requestor_recipient_data_label_history(recipient, label)
        )
    end
  end

  def requestor_recipient_data_with_filter(conn, %{
        "id" => rid,
        "form_submission_id" => raw_form_submission_id,
        "contents_id" => raw_contents_id
      }) do
    form_submission_id =
      if raw_form_submission_id == nil do
        nil
      else
        String.to_integer(raw_form_submission_id)
      end

    contents_id =
      if raw_contents_id == nil do
        nil
      else
        String.to_integer(raw_contents_id)
      end

    recipient = Repo.get(Recipient, rid)
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("Forbidden")

      recipient == nil ->
        conn |> put_status(404) |> text("Not Found")

      requestor.company_id != recipient.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        render(conn, "data_tab.json",
          data_tab:
            api_requestor_recipient_data(recipient,
              form_submission_id: form_submission_id,
              contents_id: contents_id
            )
        )
    end
  end

  def requestor_recipients_paginated(conn, params) do
    show_deleted_recipients = params["show_deleted_recipients"] || false
    # filter = params["filter"] || "none"
    search = params["search"] || ""
    sort = String.to_atom(params["sort"] || "name")
    sort_direction = String.to_atom(params["sort_direction"] || "asc")
    {page, _} = Integer.parse(Helpers.get_param(params, "page", "1"))
    {per_page, _} = Integer.parse(Helpers.get_param(params, "per_page", "20"))

    r_status = if show_deleted_recipients, do: -1, else: 1

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    search_string = "%#{search}%"

    data =
      if search != "" do
        case sort do
          :email ->
            Repo.all(
              from r in Recipient,
                join: u in User,
                on: u.id == r.user_id,
                where:
                  r.company_id == ^company.id and
                    r.status != ^r_status and
                    (like(fragment("lower(?)", r.name), fragment("lower(?)", ^search_string)) or
                       like(fragment("lower(?)", u.email), fragment("lower(?)", ^search_string)) or
                       like(
                         fragment("lower(?)", r.organization),
                         fragment("lower(?)", ^search_string)
                       )),
                limit: ^per_page,
                offset: ^((page - 1) * per_page),
                order_by: [{^sort_direction, field(u, ^sort)}],
                select: r
            )

          _ ->
            Repo.all(
              from r in Recipient,
                join: u in User,
                on: u.id == r.user_id,
                where:
                  r.company_id == ^company.id and
                    r.status != ^r_status and
                    (like(fragment("lower(?)", r.name), fragment("lower(?)", ^search_string)) or
                       like(fragment("lower(?)", u.email), fragment("lower(?)", ^search_string)) or
                       like(
                         fragment("lower(?)", r.organization),
                         fragment("lower(?)", ^search_string)
                       )),
                limit: ^per_page,
                offset: ^((page - 1) * per_page),
                order_by: [{^sort_direction, field(r, ^sort)}],
                select: r
            )
        end
      else
        case sort do
          :email ->
            Repo.all(
              from r in Recipient,
                join: u in User,
                on: u.id == r.user_id,
                where: r.company_id == ^company.id and r.status != ^r_status,
                limit: ^per_page,
                offset: ^((page - 1) * per_page),
                order_by: [{^sort_direction, field(u, ^sort)}],
                select: r
            )

          _ ->
            Repo.all(
              from r in Recipient,
                join: u in User,
                on: u.id == r.user_id,
                where: r.company_id == ^company.id and r.status != ^r_status,
                limit: ^per_page,
                offset: ^((page - 1) * per_page),
                order_by: [{^sort_direction, field(r, ^sort)}],
                select: r
            )
        end
      end

    [total_rows] =
      if search != "" do
        Repo.all(
          from r in Recipient,
            join: u in User,
            on: u.id == r.user_id,
            where:
              r.company_id == ^company.id and
                (like(fragment("lower(?)", r.name), fragment("lower(?)", ^search_string)) or
                   like(fragment("lower(?)", u.email), fragment("lower(?)", ^search_string)) or
                   like(
                     fragment("lower(?)", r.organization),
                     fragment("lower(?)", ^search_string)
                   )),
            select: count(r.id)
        )
      else
        Repo.all(
          from r in Recipient,
            where: r.company_id == ^company.id,
            select: count(r.id)
        )
      end

    total_pages = ceil(total_rows / per_page)

    conn
    |> render("recipients_paginated.json",
      data: data,
      total_pages: total_pages,
      page: page,
      has_next: page < total_pages,
      count: total_rows
    )
  end

  def recipient_restore(recp) do
    changes = %{
      status: 0
    }

    cs = Recipient.changeset(recp, changes)
    Repo.update!(cs)
  end

  def handle_recipient_restore(conn, %{"id" => id} = _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = Repo.get(Recipient, id)
    company = Repo.get(Company, recipient.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      recipient_restore(recipient)
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, id)
      conn |> json(%{msg: "OK", id: id})
    else
      conn |> put_status(401) |> text("Forbidden")
    end
  end

  def requestor_recipients(conn, params) do
    filter = params["filter"] || "none"

    company = get_current_requestor(conn, as: :company)

    if company == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      data =
        case filter do
          "none" ->
            Repo.all(
              from r in Recipient,
                where: r.company_id == ^company.id,
                join: u in User,
                on: u.id == r.user_id,
                order_by: r.name,
                select: r
            )

          "hidden" ->
            Repo.all(
              from r in Recipient,
                where: r.company_id == ^company.id and r.show_in_dashboard == false,
                join: u in User,
                on: u.id == r.user_id,
                order_by: r.name,
                select: r
            )
        end
        |> Enum.sort_by(&String.downcase(&1.name), :asc)

      render(conn, "recipients.json", recipients: data)
    end
  end

  def requestor_recipient_exists(conn, %{"email" => email}) do
    email = String.trim(String.downcase(email))
    company = get_current_requestor(conn, as: :company)

    user =
      Repo.one(
        from r in Recipient,
          join: u in User,
          on: r.user_id == u.id,
          where: r.company_id == ^company.id and u.email == ^email,
          select: r
      )

    if company != nil and user != nil do
      json(conn, %{exists: true, id: user.id})
    else
      json(conn, %{exists: false})
    end
  end

  def requestor_put_recipient(conn, %{
        "id" => id,
        "name" => name,
        "organization" => org,
        "email" => email,
        "phone_number" => phone_number,
        "start_date" => start_date,
        "tags" => tags
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    case api_edit_recipient(
           us_user,
           id,
           org,
           name,
           email,
           phone_number,
           start_date,
           tags
         ) do
      {:ok, :email_changed} ->
        text(conn, "EMAIL")

      {:ok, _} ->
        text(conn, "OK")

      {:error, :forbidden} ->
        conn |> put_status(403) |> text("duplicate_email")

      {:error, t} ->
        conn |> put_status(400) |> text(t)
    end
  end

  def requestor_recipient_with_id(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)
    recp = Repo.get(Recipient, id)

    if requestor != nil do
      if recp.company_id != requestor.company_id do
        conn |> put_status(403) |> json(%{error: :forbidden})
      else
        render(conn, "recipient.json", recipient: recp)
      end
    else
      me_as_recipient =
        Repo.get_by(Recipient, %{status: 0, user_id: us_user.id, company_id: recp.company_id})

      if me_as_recipient != nil do
        render(conn, "recipient.json", recipient: recp)
      else
        conn |> put_status(403) |> json(%{error: :forbidden})
      end
    end
  end

  def api_new_recipient(company, name, email, org, phone_number, start_date, tags \\ []) do
    org =
      if org == nil or org == "" do
        " "
      else
        org
      end

    email = String.trim(String.downcase(email))

    cond do
      invitation_ok?(name, email, org, company) != :ok ->
        {:error, :bad_data}

      User.exists?(email) ->
        user = Repo.one(from u in User, where: u.email == ^email, select: u)

        if Recipient.exists?(email, company) do
          recipient =
            Repo.get_by(Recipient, %{
              user_id: user.id,
              company_id: company.id
            })

          {:error, {:already_exists, recipient.id, recipient.status == 1}}
        else
          rcp =
            Repo.insert!(%Recipient{
              company_id: company.id,
              name: name,
              organization: org,
              status: 0,
              terms_accepted: false,
              user_id: user.id,
              phone_number: phone_number,
              start_date: start_date
            })

          {:ok, rcp.id}
        end

      true ->
        new = %User{
          name: name,
          email: String.downcase(email),
          company_id: company.id,
          organization: org,
          verified: true,
          verification_code: User.new_password(16),
          admin_of: nil,
          access_code: "null",
          username: "null",
          flags: 0,
          password_hash: User.hash_password(User.new_password(32)),
          current_document_index: 0
        }

        n = Repo.insert!(new)

        rcp =
          Repo.insert!(%Recipient{
            company_id: company.id,
            name: name,
            organization: org,
            status: 0,
            terms_accepted: false,
            user_id: n.id,
            phone_number: phone_number,
            start_date: start_date,
            tags: tags
          })

        {:ok, rcp.id}
    end
  end

  def requestor_new_recipient(conn, params) do
    org = params["organization"] || nil
    name = params["name"] || nil
    email = params["email"] || nil
    phone_number = params["phone_number"] || nil
    start_date = Helpers.get_utc_date(params["start_date"])
    tags = params["tags"] || []

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    case api_new_recipient(company, name, email, org, phone_number, start_date, tags) do
      {:ok, rid} ->
        conn |> put_status(200) |> json(%{id: rid})

      {:error, :bad_data} ->
        conn |> put_status(400) |> json(%{error: :bad_data})

      {:error, {:already_exists, rid, is_deleted}} ->
        conn |> put_status(400) |> json(%{error: :already_exists, id: rid, is_deleted: is_deleted })
    end
  end

  def requestor_bulk_new_recipient(conn, %{"recipients" => recps}) do
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> json(%{error: :forbidden})

      Enum.empty?(recps) ->
        conn |> put_status(400) |> json(%{error: :empty_recipients})

      true ->
        company = Repo.get(Company, requestor.company_id)

        results =
          recps
          |> Enum.map(fn recp ->
            api_new_recipient(company, recp["name"], recp["email"], recp["organization"], "", nil, [])
          end)
          |> Enum.group_by(fn x ->
            case x do
              {:error, _} -> :error
              {:ok, _} -> :ok
            end
          end)

        json(conn, %{
          success: length(results[:ok] || []),
          failure: length(results[:error] || [])
        })
    end
  end

  def requestor_delete_recipient(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    recipient = Repo.get(Recipient, id)
    company = Repo.get(Company, requestor.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      reply = BoilerPlateWeb.UserController.api_delete_user(requestor, us_user, id)

      if reply == :ok do
        from(pa in PackageAssignment,
          where: pa.recipient_id == ^recipient.id,
          update: [set: [status: 1, recipient_id: -1, deleted_recipient_id: ^recipient.id]]
        )
        |> Repo.update_all([])

        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
        text(conn, "OK")
      else
        conn |> put_status(400) |> json(%{error: reply})
      end
    else
      conn |> put_status(401) |> text("Forbidden")
    end
  end

  def requestor_hide_recipient(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    reply = BoilerPlateWeb.UserController.api_archive_user(us_user, id)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def requestor_show_recipient(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    reply = BoilerPlateWeb.UserController.api_show_user(us_user, id)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end
end
