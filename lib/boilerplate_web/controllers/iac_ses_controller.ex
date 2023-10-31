import Bitwise
import Ecto.Query
import BoilerPlate.AuditLog
alias BoilerPlate.ExperimentalHack
alias BoilerPlate.Company
alias BoilerPlate.Package
alias BoilerPlate.IACAppendix
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACAssignedForm
alias BoilerPlate.IACField
alias BoilerPlate.Recipient
alias BoilerPlate.PackageContents
alias BoilerPlate.Repo
alias BoilerPlate.RawDocument
alias BoilerPlate.Form
alias BoilerPlate.Recipient
alias BoilerPlate.User
alias BoilerPlate.IACSESExportable

defmodule BoilerPlateWeb.IACSESController do
  use BoilerPlateWeb, :controller

  ###
  ### Helpers
  ###

  # Set a field's value based on the master_field_id found in the field_map
  defp ses_set_field(new_contents?, field, master_field_id, field_map) do
    field_data =
      field_map
      |> Enum.find(fn x ->
        (x["target_field"] != 0 and x["target_field"] == master_field_id) ||
          (x["target_label"] != nil and field.label != nil and
             field.label != "" and x["target_label"] != "" and
             x["target_label"] == field.label and
             ((x["type"] != "checkbox" and x["type"] != "radio") or
                (field.label_value != "" and field.label_value != nil and x["field_value"] != "" and
                   x["field_value"] != nil and
                   (field.label_value == x["field_value"] or
                      (is_list(x["field_value"]) and
                         Enum.member?(List.flatten(x["field_value"]), field.label_value))))))
      end)

    IO.puts(
      "ses_set_field(new_contents = #{new_contents?}, field.id=#{field.id}, field.label=#{field.label}, master_field_id=#{master_field_id})"
    )

    # IO.inspect(field_map, label: "field_map")
    # IO.inspect(field_data, label: "field_data")

    if field_data == nil do
      if new_contents? do
        Repo.update!(
          IACField.changeset(field, %{
            default_value: "",
            set_value: ""
          })
        )
      end
    else
      case field_data["type"] do
        "text" ->
          Repo.update!(
            IACField.changeset(field, %{
              default_value: to_string(field_data["value"]),
              set_value: to_string(field_data["value"])
            })
          )

        "checkbox" ->
          Repo.update!(
            IACField.changeset(field, %{
              default_value:
                if field_data["checked"] do
                  "true"
                else
                  "false"
                end,
              set_value:
                if field_data["checked"] do
                  "true"
                else
                  "false"
                end
            })
          )

        _ ->
          raise "invalid field_data type #{field_data["type"]}"
      end
    end
  end

  # [Hack] Crimson support for etag fill
  # https://bugs.internal.boilerplate.co/issues/8289
  def old_method_ses_set_text(new_contents?, m, master_id, field, fill) do
    field_data = m |> Enum.filter(&(&1["to"] == master_id))

    if Enum.empty?(field_data) do
      if new_contents? do
        Repo.update!(
          IACField.changeset(field, %{
            default_value: "",
            set_value: ""
          })
        )
      end
    else
      for info <- field_data do
        field = Repo.get(IACField, field.id)
        set_txt = field.set_value
        from = info["from"]

        txt =
          cond do
            Map.has_key?(info, "merge_with") ->
              merge_key = info["merge_with"]
              val = Enum.filter(fill["data"], &(&1["key"] == from))
              new_txt = hd(val)["val"]
              "#{set_txt}#{merge_key}#{new_txt}"

            True ->
              val = Enum.filter(fill["data"], &(&1["key"] == from))
              hd(val)["val"]
          end

        Repo.update!(
          IACField.changeset(field, %{
            default_value: txt,
            set_value: txt
          })
        )
      end
    end
  end

  defp old_method_find_ehck(ehck, ses_type, ses_select_target, checklist_id) do
    ehck["checklist_id"] == checklist_id and
      (ses_type == "nonselect" || ses_select_target == ehck["raw_document_id"])
  end

  defp old_method_do_prep(target_checklist_id, recipient, iac_doc, imf) do
    target_checklist =
      if target_checklist_id != nil do
        Repo.get(Package, target_checklist_id)
      else
        nil
      end

    if target_checklist == nil do
      raise ArgumentError, message: "no target_checklist for 8289"
    end

    # Create an assignment and pre-fill the document
    contents =
      PackageContents.get_if_exists(
        recipient,
        target_checklist
      )

    {new_contents, contents} =
      if contents == nil do
        {true,
         PackageContents.inprogress_package(
           recipient,
           target_checklist
         )}
      else
        {false, contents}
      end

    iaf =
      BoilerPlateWeb.IACController.get_iaf_for(
        recipient,
        Repo.get(Company, recipient.company_id),
        iac_doc,
        contents,
        imf
      )

    # XXX: is this needed? we need to make sure the field ids are correct
    iaf = Repo.get(IACAssignedForm, iaf.id)

    {iaf, new_contents, contents}
  end

  defp old_method_do_prefill(iaf, new_contents?, contents, iac_doc, field_map, filldata) do
    for field_id <- iaf.fields do
      field = Repo.get(IACField, field_id)
      master_field_id = field.master_field_id

      old_method_ses_set_text(
        new_contents?,
        field_map,
        master_field_id,
        field,
        filldata
      )
    end

    # Update the IAF to appear pre-filled
    cs =
      IACAssignedForm.changeset(iaf, %{
        flags: iaf.flags ||| 1
      })

    Repo.update!(cs)

    {:ok, :prefill, contents.id, iac_doc.id}
  end

  defp old_method_do_autoprefill(iaf, new_contents?, contents, iac_doc, field_map) do
    # Automatic pre-fill, target fields are grabbed from the questionnaire
    # while additional setup data is grabbed using the experimental hack stuff
    # above.

    for field_id <- iaf.fields do
      field = Repo.get(IACField, field_id)
      master_field_id = field.master_field_id
      ses_set_field(new_contents?, field, master_field_id, field_map)
    end

    # Update the IAF to appear pre-filled
    cs =
      IACAssignedForm.changeset(iaf, %{
        flags: iaf.flags ||| 1
      })

    Repo.update!(cs)

    {:ok, :prefill, contents.id, iac_doc.id}
  end

  ###
  ### Internal API
  ###

  # Generate an appendix based on an appendix struct
  def api_iac_ses_generate_appendix(apxs) do
    japxs = Jason.encode!(apxs)
    apxid = for _ <- 1..10, into: "", do: <<Enum.random('0123456789abcdef')>>

    # Write the JSON to a temporary location
    # {:ok, tmp_json_path} = Briefly.create(prefix: "boilerplate")
    tmp_json_path = "/tmp/appendix-#{apxid}.json"
    File.write!(tmp_json_path, japxs)

    # Create a temporary file for the final PDF
    # {:ok, tmp_final_path} = Briefly.create(prefix: "boilerplate")
    tmp_final_path = "/tmp/appendix-#{apxid}.pdf"

    # Create the appendix
    appendixwrap = "#{File.cwd() |> elem(1)}/tools/iac/filler/appendixwrap.sh"

    {output, _exit_status} =
      System.cmd(appendixwrap, [tmp_json_path, tmp_final_path],
        env: [
          {"PYTHON_RUN_CMD", Application.get_env(:boilerplate, :iac_python_runcmd)}
        ],
        stderr_to_stdout: true
      )

    IO.inspect(output, label: "[api_iac_ses_generate_appendix/apxid:#{apxid}]")

    {:ok, tmp_final_path}
  end

  # Create the appendix struct and generate it
  def api_iac_ses_update_appendix(iax, contents, requestor, iaf, prepare_time_str, repeat_data) do
    api_iac_ses_make_or_update_appendix(
      :update,
      iax,
      contents,
      requestor,
      iaf,
      prepare_time_str,
      repeat_data,
      nil
    )
  end

  def api_iac_ses_make_appendix(
        contents,
        requestor,
        iaf,
        prepare_time_str,
        repeat_data,
        appendix_order
      ) do
    api_iac_ses_make_or_update_appendix(
      :create,
      nil,
      contents,
      requestor,
      iaf,
      prepare_time_str,
      repeat_data,
      appendix_order
    )
  end

  def api_iac_ses_make_or_update_appendix(
        action,
        iax,
        contents,
        requestor,
        iaf,
        prepare_time_str,
        repeat_data,
        appendix_order
      ) do
    form_data = repeat_data["data"]

    if Enum.empty?(form_data) do
      {:skip, :empty_form}
    else
      form = Repo.get(Form, repeat_data["formId"])

      form_submission =
        BoilerPlateWeb.FormController.get_last_form_submission(form.id, contents.id)

      recipient = Repo.get(Recipient, contents.recipient_id)

      headers = Enum.map(form_data |> Enum.at(0), & &1["name"])

      values =
        Enum.map(form_data, fn entry ->
          Enum.map(entry, & &1["value"])
        end)

      appendix_struct = %{
        checklist_title: contents.title,
        form_title: form.title,
        recipient_name: recipient.name,
        recipient_company: recipient.organization,
        requestor_name: requestor.name,
        requestor_company: requestor.organization,
        submit_date:
          form_submission.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
        prepare_date: prepare_time_str,
        form_headers: headers,
        form_values: values
      }

      # generate the appendix and get back the temporary file name
      {:ok, appendix_filename} =
        case api_iac_ses_generate_appendix(appendix_struct) do
          {:ok, filen} -> {:ok, filen}
          {:error, msg} -> raise ArgumentError, message: "failed to generate appendix: #{msg}"
        end

      new_iax =
        case action do
          :create ->
            final_filename = UUID.uuid4() <> ".pdf"

            # Now store the file on S3
            IACAppendix.store(%{
              filename: final_filename,
              path: appendix_filename
            })

            # Create the appendix
            Repo.insert!(%IACAppendix{
              iac_assigned_form_id: iaf.id,
              form_id: form.id,
              appendix_name: final_filename,
              appendix_order: appendix_order,
              version: 0,
              status: 0,
              flags: 0
            })

          :update ->
            final_filename = UUID.uuid4() <> ".pdf"

            # Now store the file on S3
            IACAppendix.store(%{
              filename: final_filename,
              path: appendix_filename
            })

            # update the appendix
            Repo.update!(IACAppendix.changeset(iax, %{appendix_name: final_filename}))

          _ ->
            raise ArgumentError,
              message: "api_iac_ses_generate_appendix, invalid action: #{action}"
        end

      {:ok, new_iax.appendix_name}
    end
  end

  def api_iac_get_appendix(repeat_data, iaf, contents) do
    form_data = repeat_data["data"]

    if Enum.empty?(form_data) do
      {:skip, :empty_form}
    else
      form = Repo.get(Form, repeat_data["formId"])

      form_submission =
        BoilerPlateWeb.FormController.get_last_form_submission(form.id, contents.id)

      case Repo.get_by(IACAppendix, %{
             status: 0,
             version: 0,
             form_id: form.id,
             iac_assigned_form_id: iaf.id
           }) do
        nil ->
          :missing

        iax ->
          if iax.updated_at < form_submission.updated_at do
            {:update, iax}
          else
            {:ok, iax.appendix_name}
          end
      end
    end
  end

  # Generate appendix PDFs per the repeat_data, one for each.
  def api_iac_ses_make_appendices(contents, requestor, iaf, repeat_data) do
    IO.inspect(repeat_data, label: "api_iac_ses_make_appendices/repeat_data")

    prepare_time = DateTime.utc_now()
    prepare_time_str = prepare_time |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC")

    for {appendix_order, rd} <- Enum.with_index(repeat_data, fn e, i -> {i, e} end) do
      case api_iac_get_appendix(rd, iaf, contents) do
        {:ok, apx_fn} ->
          {:ok, apx_fn}

        {:skip, m} ->
          {:skip, m}

        {:update, iax} ->
          api_iac_ses_update_appendix(iax, contents, requestor, iaf, prepare_time_str, rd)

        :missing ->
          api_iac_ses_make_appendix(
            contents,
            requestor,
            iaf,
            prepare_time_str,
            rd,
            appendix_order
          )
      end
    end
  end

  # SEtup an IACDocument as a SES fillable, but retrieve the data from the user's profile.
  def api_iac_ses_fill(
        requestor,
        :recipient,
        recipient,
        _checklist,
        _contents_id,
        _field_map,
        filldata
      ) do
    ses_select_target = filldata["raw_document_id"] || 0

    # Find an IES for this raw_document_id, it doesn't matter which checklist it
    # originates from as we'll be using the data from the profile of the
    # recipient.
    ies =
      Repo.one(
        from iesex in IACSESExportable,
          where:
            is_nil(iesex.contents_id) and iesex.status == 0 and iesex.version == 0 and
              iesex.raw_document_id == ^ses_select_target,
          order_by: [desc: iesex.inserted_at],
          limit: 1,
          select: iesex
      )

    ies =
      if ies == nil do
        # Create an IES now to allow this to be exported and use it
        {:ok, ise_id} =
          BoilerPlateWeb.IACController.create_ses_exportable(
            nil,
            ses_select_target,
            Repo.get(Company, recipient.company_id)
          )

        Repo.get(IACSESExportable, ise_id)
      else
        ies
      end

    # We have a valid IES, now retrieve the data from the profile of the user.
    # But first, check if there are filters applied.
    data =
      if Map.has_key?(filldata, "filterDetails") and filldata["filterDetails"]["type"] != nil do
        filter_details = filldata["filterDetails"]
        filter_type = filter_details["type"]
        filter_params = filter_details["params"]

        filter =
          cond do
            filter_type == "cs" ->
              contents_filter = filter_params["contents_id"]

              if contents_filter == nil do
                [contents_id: nil]
              else
                [
                  contents_id:
                    if is_integer(contents_filter) do
                      contents_filter
                    else
                      String.to_integer(contents_filter)
                    end
                ]
              end

            filter_type == "fs" ->
              fs_filter = filter_params["form_submission_id"]

              if fs_filter == nil do
                [form_submission_id: nil]
              else
                [
                  form_submission_id:
                    if is_integer(fs_filter) do
                      fs_filter
                    else
                      String.to_integer(fs_filter)
                    end
                ]
              end
          end

        BoilerPlateWeb.RecipientController.api_requestor_recipient_data(recipient, filter)
      else
        # No filter
        BoilerPlateWeb.RecipientController.api_requestor_recipient_data(recipient)
      end

    # Do some setup
    target_checklist_id = ies.target_checklist_id
    target_checklist = Repo.get(Package, target_checklist_id)
    iac_doc = Repo.get(IACDocument, ies.iac_document_id)
    imf = Repo.get(IACMasterForm, iac_doc.master_form_id)
    fields = IACMasterForm.fields_of(iac_doc)

    unique_fields =
      fields
      |> Enum.map(fn field ->
        field.label
      end)
      |> Enum.uniq()

    IO.inspect(unique_fields, label: "unique_fields")

    # Create an assignment and pre-fill the document
    contents =
      PackageContents.get_if_exists(
        recipient,
        target_checklist
      )

    {_new_contents?, contents} =
      if contents == nil do
        {true,
         PackageContents.inprogress_package(
           recipient,
           target_checklist
         )}
      else
        {false, contents}
      end

    iaf =
      BoilerPlateWeb.IACController.get_iaf_for(
        recipient,
        Repo.get(Company, recipient.company_id),
        iac_doc,
        contents,
        imf
      )

    # XXX: is this needed? we need to make sure the field ids are correct
    iaf = Repo.get(IACAssignedForm, iaf.id)

    # We have the data, now convert it into the normal format that SES requires.
    unique_label_data =
      data
      |> Enum.filter(fn %{label: l} -> Enum.member?(unique_fields, l) end)

    # Find all table fields in the document
    table_labels =
      fields
      |> Enum.map(fn field -> {field.label, field.field_type} end)
      |> Enum.filter(fn {_, t} -> t == 4 end)
      |> Enum.map(fn {l, _} -> l end)

    # Tables that we send to SES but are empty
    empty_tables_based_on_data =
      unique_label_data
      |> Enum.filter(fn %{label: _l, type: t, value: v, source: _s} ->
        t == "repeat" and Enum.empty?(v)
      end)
      |> Enum.map(fn %{label: l} -> l end)

    # Table fields that don't get data in this export.
    empty_tables_that_arent_sent =
      Enum.filter(
        table_labels,
        fn label ->
          Enum.find(unique_label_data, fn %{label: l} -> l == label end) == nil
        end
      )

    empty_tables = empty_tables_based_on_data ++ empty_tables_that_arent_sent

    proper_data =
      unique_label_data
      |> Enum.flat_map(fn %{label: l, type: t, value: v, source: s} ->
        case t do
          "checkbox" ->
            Enum.map(v, fn x ->
              %{
                "type" => "checkbox",
                "field_value" => x,
                "target_label" => l,
                "target_field" => 0,
                "checked" => true
              }
            end)

          "radio" ->
            [
              %{
                "type" => "checkbox",
                "field_value" => v,
                "target_label" => l,
                "target_field" => 0,
                "checked" => true
              }
            ]

          "number" ->
            [
              %{
                "type" => "text",
                "target_label" => l,
                "target_field" => 0,
                "field_value" => "",
                "value" => to_string(v)
              }
            ]

          "repeat" ->
            if Enum.empty?(v) do
              # Empty!
              []
            else
              # Figure out the headers
              sample_entry = v |> Enum.at(0)

              headers =
                v
                |> Enum.at(0)
                |> Map.keys()

              sorted_headers =
                Enum.sort(headers, fn a, b ->
                  sample_value = sample_entry[headers |> Enum.at(0)]

                  cond do
                    Map.has_key?(sample_value, "fieldId") ->
                      a_i =
                        if is_integer(sample_entry[a]["fieldId"]) do
                          sample_entry[a]["fieldId"]
                        else
                          String.to_integer(sample_entry[a]["fieldId"])
                        end

                      b_i =
                        if is_integer(sample_entry[b]["fieldId"]) do
                          sample_entry[b]["fieldId"]
                        else
                          String.to_integer(sample_entry[b]["fieldId"])
                        end

                      a_i < b_i

                    Map.has_key?(sample_value, :fieldId) ->
                      a_i =
                        if is_integer(sample_entry[a][:fieldId]) do
                          sample_entry[a][:fieldId]
                        else
                          String.to_integer(sample_entry[a][:fieldId])
                        end

                      b_i =
                        if is_integer(sample_entry[b][:fieldId]) do
                          sample_entry[b][:fieldId]
                        else
                          String.to_integer(sample_entry[b][:fieldId])
                        end

                      a_i < b_i

                    Map.has_key?(sample_value, "sort_order") ->
                      sample_entry[a]["sort_order"] < sample_entry[b]["sort_order"]

                    Map.has_key?(sample_value, :sort_order) ->
                      sample_entry[a][:sort_order] < sample_entry[b][:sort_order]
                  end
                end)

              values =
                v
                |> Enum.map(&Map.values/1)
                |> Enum.map(fn x ->
                  x
                  |> Enum.sort(fn a, b ->
                    cond do
                      Map.has_key?(a, "fieldId") ->
                        a_i =
                          if is_integer(a["fieldId"]) do
                            a["fieldId"]
                          else
                            String.to_integer(a["fieldId"])
                          end

                        b_i =
                          if is_integer(b["fieldId"]) do
                            b["fieldId"]
                          else
                            String.to_integer(b["fieldId"])
                          end

                        a_i < b_i

                      Map.has_key?(a, :fieldId) ->
                        a_i =
                          if is_integer(a[:fieldId]) do
                            a[:fieldId]
                          else
                            String.to_integer(a[:fieldId])
                          end

                        b_i =
                          if is_integer(b[:fieldId]) do
                            b[:fieldId]
                          else
                            String.to_integer(b[:fieldId])
                          end

                        a_i < b_i

                      Map.has_key?(a, "sort_order") ->
                        a["sort_order"] < b["sort_order"]

                      Map.has_key?(a, :sort_order) ->
                        a[:sort_order] < b[:sort_order]
                    end
                  end)
                  |> Enum.map(fn y ->
                    y.value
                  end)
                end)

              # Create the IACAppendix
              appendix_struct = %{
                checklist_title: s.origin,
                form_title: "",
                recipient_name: recipient.name,
                recipient_company: recipient.organization,
                requestor_name: requestor.name,
                requestor_company: requestor.organization,
                submit_date: "N/A",
                prepare_date:
                  DateTime.utc_now()
                  |> DateTime.truncate(:second)
                  |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM} UTC"),
                form_headers: sorted_headers,
                form_values: values
              }

              # generate the appendix and get back the temporary file name
              {:ok, appendix_filename} =
                case api_iac_ses_generate_appendix(appendix_struct) do
                  {:ok, filen} ->
                    {:ok, filen}

                  {:error, msg} ->
                    raise ArgumentError, message: "failed to generate appendix: #{msg}"
                end

              final_filename = UUID.uuid4() <> ".pdf"

              # Now store the file on S3
              IACAppendix.store(%{
                filename: final_filename,
                path: appendix_filename
              })

              # Create or update the appendix
              iax =
                Repo.one(
                  from ia in IACAppendix,
                    where:
                      ia.iac_assigned_form_id == ^iaf.id and
                        is_nil(ia.form_id) and
                        ia.appendix_label == ^l and
                        ia.version == 0 and
                        ia.status == 0,
                    select: ia
                )

              if iax == nil do
                Repo.insert!(%IACAppendix{
                  iac_assigned_form_id: iaf.id,
                  form_id: nil,
                  appendix_name: final_filename,
                  appendix_reference: s.origin,
                  appendix_label: l,
                  appendix_order: 0,
                  version: 0,
                  status: 0,
                  flags: 0
                })
              else
                Repo.update!(IACAppendix.changeset(iax, %{appendix_name: final_filename}))
              end

              # Return an empty array as no fields have to be set.
              []
            end

          _ ->
            [
              %{
                "type" => "text",
                "target_label" => l,
                "target_field" => 0,
                "field_value" => "",
                "value" => v
              }
            ]
        end
      end)

    # IO.inspect(proper_data, label: "proper_data")

    for field_id <- iaf.fields do
      field = Repo.get(IACField, field_id)
      master_field_id = field.master_field_id

      ses_set_field(true, field, master_field_id, proper_data)
    end

    # Update the IAF to appear pre-filled
    cs =
      IACAssignedForm.changeset(iaf, %{
        flags: iaf.flags ||| 1
      })

    Repo.update!(cs)

    {:ok, :prefill, contents.id, iac_doc.id, empty_tables}
  end

  # Setup an IACDocument as a SES fillable
  def api_iac_ses_fill(
        requestor,
        :exportable,
        recipient,
        _checklist,
        contents_id,
        field_map,
        filldata
      ) do
    ses_select_target = filldata["raw_document_id"] || 0
    # Find the IACSESExportable for this checklist
    ies =
      Repo.get_by(IACSESExportable, %{
        status: 0,
        raw_document_id: ses_select_target,
        contents_id: contents_id
      })

    if ies != nil do
      target_checklist_id = ies.target_checklist_id
      target_checklist = Repo.get(Package, target_checklist_id)
      iac_doc = Repo.get(IACDocument, ies.iac_document_id)
      imf = Repo.get(IACMasterForm, iac_doc.master_form_id)

      # Create an assignment and pre-fill the document
      contents =
        PackageContents.get_if_exists(
          recipient,
          target_checklist
        )

      {new_contents?, contents} =
        if contents == nil do
          {true,
           PackageContents.inprogress_package(
             recipient,
             target_checklist
           )}
        else
          {false, contents}
        end

      iaf =
        BoilerPlateWeb.IACController.get_iaf_for(
          recipient,
          Repo.get(Company, recipient.company_id),
          iac_doc,
          contents,
          imf
        )

      # XXX: is this needed? we need to make sure the field ids are correct
      iaf = Repo.get(IACAssignedForm, iaf.id)

      # Filter and work on the repeat entries before passing it to ses_set_field/4
      {repeat_data, non_repeat_field_map} = Enum.split_with(field_map, &(&1["type"] == "repeat"))

      if Enum.empty?(repeat_data) do
        []
      else
        api_iac_ses_make_appendices(
          Repo.get(PackageContents, contents_id),
          requestor,
          iaf,
          repeat_data
        )
      end

      for field_id <- iaf.fields do
        field = Repo.get(IACField, field_id)
        master_field_id = field.master_field_id

        ses_set_field(new_contents?, field, master_field_id, non_repeat_field_map)
      end

      # Update the IAF to appear pre-filled
      cs =
        IACAssignedForm.changeset(iaf, %{
          flags: iaf.flags ||| 1
        })

      Repo.update!(cs)

      {:ok, :prefill, contents.id, iac_doc.id}
    else
      {:err, :missing_ies}
    end
  end

  def api_iac_ses_fill(_requestor, :old, recipient, checklist, _, field_map, filldata) do
    ses_type = filldata["type"] || "nonselect"
    ses_select_target = filldata["raw_document_id"] || 0

    # Check if the checklist id is part of an active crimson HACK
    ehcks = Repo.all(from e in ExperimentalHack, where: e.ticket_id == 8289, select: e)

    data =
      ehcks
      |> Enum.map(&Poison.decode!(&1.data))
      |> Enum.find(&old_method_find_ehck(&1, ses_type, ses_select_target, checklist.id))

    # IO.inspect(data)

    # Found a valid, active hack
    hack_data = data["data"]
    # IO.inspect(hack_data)

    iac_doc = Repo.get(IACDocument, data["iac_document_id"])
    imf = Repo.get(IACMasterForm, iac_doc.master_form_id)

    {iaf, new_contents?, contents} =
      old_method_do_prep(data["target_checklist_id"], recipient, iac_doc, imf)

    case data["type"] do
      "autoprefill" ->
        old_method_do_autoprefill(
          iaf,
          new_contents?,
          contents,
          iac_doc,
          field_map
        )

      "prefill" ->
        old_method_do_prefill(
          iaf,
          new_contents?,
          contents,
          iac_doc,
          hack_data["map"],
          filldata
        )

      _ ->
        {:err, :invalid_old_fill_type}
    end
  end

  # Return the list of templates that this checklist can be filled into
  def api_iac_ses_targets(requestor, checklistId) do
    if requestor == nil do
      audit(:iac_ses_targets_failure, %{
        user: Repo.get(User, requestor.user_id),
        requestor_id: requestor.id,
        checklist_id: checklistId,
        reason: 2
      })

      {:err, :forbidden}
    else
      # Check if the checklist id is part of an active 8289/8508  HACK
      ehck =
        Repo.one(from e in BoilerPlate.ExperimentalHack, where: e.ticket_id == 8508, select: e)

      data = Poison.decode!(ehck.data)
      expected_key = "checklist_#{checklistId}"

      if data |> Map.has_key?(expected_key) do
        audit(:iac_ses_targets, %{
          user: Repo.get(User, requestor.user_id),
          requestor_id: requestor.id,
          checklist_id: checklistId,
          response_type: :old
        })

        {:ok, data[expected_key]}
      else
        # Check if there is any IACSESExportable
        ies =
          Repo.all(
            from ise in IACSESExportable,
              where: ise.checklist_id == ^checklistId and ise.status == 0 and ise.version == 0,
              select: ise
          )

        if ies == nil or ies == [] do
          audit(:iac_ses_targets_failure, %{
            user: Repo.get(User, requestor.user_id),
            requestor_id: requestor.id,
            checklist_id: checklistId,
            reason: 1
          })

          {:err, :not_found}
        else
          audit(:iac_ses_targets, %{
            user: Repo.get(User, requestor.user_id),
            requestor_id: requestor.id,
            checklist_id: checklistId,
            response_type: :ies
          })

          {:ok, Enum.map(ies, & &1.raw_document_id)}
        end
      end
    end
  end

  ###
  ### Controller stuff
  ###

  # Create a digital form using data from IAC
  def iac_ses_post_form(conn, %{"template_id" => rdid, "form" => form_data}) do
    # TODO: link the resulting form.
    requestor = get_current_requestor(conn)
    rd = Repo.get(RawDocument, rdid)

    if requestor == nil or rd.company_id != requestor.company_id do
      conn |> put_status(403) |> text("forbidden")
    else
      # 1. Create a checklist first.
      pkg =
        Repo.insert!(%Package{
          templates: [],
          title: form_data["title"],
          description: form_data["description"],
          company_id: requestor.company_id,
          allow_duplicate_submission: false,
          allow_multiple_requests: false,
          is_archived: false,
          enforce_due_date: false,
          due_date_type: 0,
          due_days: 0,
          status: 0
        })

      # 2. Add the form to the checklist.
      form_data
      |> Map.put("checklist_id", pkg.id)
      |> BoilerPlateWeb.FormController.create_form(has_master: false)

      # 2b. Clone the repeat entries forms into this checklist
      iac_doc = IACDocument.get_for(:raw_document, rd)

      IACMasterForm.raw_fields_of(iac_doc)
      |> Enum.filter(
        &(&1.field_type == 4 and &1.repeat_entry_form_id != nil and &1.repeat_entry_form_id != 0)
      )
      |> Enum.each(fn iac_field ->
        BoilerPlateWeb.FormController.duplicate_form_with_id_map(
          iac_field.repeat_entry_form_id,
          pkg.id
        )
      end)

      # 3. Create an IACSESExportable
      BoilerPlateWeb.IACController.create_or_update_ses_exportable_one(
        pkg.id,
        rd.id,
        Repo.get(Company, rd.company_id)
      )

      json(conn, %{package_id: pkg.id})
    end
  end

  # Main entrypoint for creating a SES fillable
  def iac_ses_fill(conn, filldata) do
    checklist_id = filldata["checklist"]
    recipient_id = filldata["recipient"]
    contents_id = filldata["contents"]

    mapsource =
      case filldata["mapsource"] do
        "exportable" -> :exportable
        "recipient" -> :recipient
        _ -> :old
      end

    recipient = Repo.get(Recipient, recipient_id)
    checklist = Repo.get(Package, checklist_id)
    requestor = get_current_requestor(conn)

    case api_iac_ses_fill(
           requestor,
           mapsource,
           recipient,
           checklist,
           contents_id,
           filldata["data"],
           filldata
         ) do
      {:ok, type, cid, iacdocid, empty_table_labels} ->
        json(conn, %{
          type: type,
          contents_id: cid,
          iac_doc_id: iacdocid,
          empty_tables: empty_table_labels
        })

      {:err, :missing_tchk, ies_id} ->
        raise ArgumentError, message: "no target_checklist for ies #{ies_id}"

      {:err, :invalid_old_fill_type} ->
        raise ArgumentError, message: "bad fill type"

      {:err, :missing_ies} ->
        raise ArgumentError, message: "no IES found"

      {:err, :no_data} ->
        raise ArgumentError, message: "no data found for recipient"
    end
  end

  # Return the list of templates that this checklist can be filled into
  def iac_ses_targets(conn, %{"cid" => checklistId}) do
    case get_current_requestor(conn) |> api_iac_ses_targets(checklistId) do
      {:ok, arr} -> conn |> json(arr)
      {:err, :forbidden} -> conn |> put_status(403) |> text("Forbidden")
      {:err, :not_found} -> conn |> put_status(404) |> text("Not Found")
      {:err, msg} -> conn |> put_status(400) |> json(%{err: msg})
      _ -> raise ArgumentError, message: "invalid response from api_iac_ses_targets"
    end
  end
end
