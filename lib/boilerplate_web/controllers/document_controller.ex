alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.User
alias BoilerPlate.Cabinet
alias BoilerPlate.Recipient
alias BoilerPlate.Package
alias BoilerPlate.PackageContents
alias BoilerPlate.PackageAssignment
alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized
alias BoilerPlate.Document
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACField
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlate.StorageProvider
import Bitwise
import Ecto.Query
import BoilerPlate.AuditLog

require Logger

defmodule BoilerPlateWeb.DocumentController do
  use BoilerPlateWeb, :controller

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  ###
  ### Helpers
  ###

  defp copy_template_with_file(base_doc, upl) do
    template_fn = UUID.uuid4() <> Path.extname(upl.filename)

    {_status, final_path} =
      RawDocument.store(%{
        filename: template_fn,
        path: upl.path
      })

    template = %RawDocument{
      name: base_doc.name,
      description: base_doc.description,
      file_name: final_path,
      type: base_doc.type,
      flags: base_doc.flags,
      company_id: base_doc.company_id,
      is_archived: base_doc.is_archived,
      tags: base_doc.tags
    }

    {:ok, Repo.insert!(template)}
  end

  defp duplicate_template(base_doc) do
    template = %RawDocument{
      name: base_doc.name,
      description: base_doc.description,
      file_name: base_doc.file_name,
      type: base_doc.type,
      flags: base_doc.flags,
      company_id: base_doc.company_id,
      is_archived: false,
      tags: base_doc.tags
    }

    {:ok, Repo.insert!(template)}
  end

  defp replace_template_in_packages(old_doc, new_doc) do
    query =
      from pkg in Package,
        where: pkg.company_id == ^old_doc.company_id and ^old_doc.id in pkg.templates,
        select: pkg

    packages = Repo.all(query)

    for pkg <- packages do
      idx = Enum.find_index(pkg.templates, &(&1 == old_doc.id))
      updated_tmpl = List.replace_at(pkg.templates, idx, new_doc.id)

      Repo.update!(Package.changeset(pkg, %{templates: updated_tmpl}))
    end

    Repo.update!(RawDocument.changeset(old_doc, %{is_archived: true}))

    :ok
  end

  # converts images to pdf
  defp convert_to_pdf(filepath, filename, file_ext)
       when file_ext in [".png", ".gif", ".jpg", ".jpeg", ".hevc", ".heic", ".heif"] do
    # remove names after spaces if any
    basefilename = Path.basename(filename, file_ext) |> String.split(" ") |> List.first()
    {:ok, tmp_final_path} = Briefly.create(prefix: basefilename, extname: ".pdf")

    convert_cmd = "#{File.cwd() |> elem(1)}/tools/convert_to_pdf.sh"

    try do
      case System.cmd(convert_cmd, [filepath, tmp_final_path],
             env: [
               {"IAC_CONVERT_IMAGE_RUNCMD",
                Application.get_env(:boilerplate, :iac_convert_image_runcmd)}
             ],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          audit(:successConvertImage, %{})
          {:ok, tmp_final_path}

        {output, error_code} ->
          error_msg = output |> String.split("\n") |> List.first()

          audit(:failureConvertImage, %{
            exit_status: "#{error_code}-#{error_msg}",
            filename: filename
          })

          {:error, filepath}
      end
    rescue
      error ->
        audit(:failureConvertImage, %{exit_status: error.original, filename: filename})
        {:error, filepath}
    end
  end

  defp convert_to_pdf(filepath, _filename, _file_ext), do: {:ok, filepath}

  defp concatenate_pdf_files(pdf_file_paths, final_path) do
    pdf_merger = "#{File.cwd() |> elem(1)}/tools/concat_pdf.sh"
    pdf_files_to_merge = Enum.join(pdf_file_paths, " ")

    try do
      case System.cmd(pdf_merger, [pdf_files_to_merge, final_path],
             env: [
               {"IAC_PDFTK_RUNCMD", Application.get_env(:boilerplate, :iac_pdftk_runcmd)}
             ],
             stderr_to_stdout: true
           ) do
        #
        {_output, 0} ->
          audit(:successMergePDF, %{})
          :ok

        {output, error_code} ->
          error_msg = output |> String.split("\n") |> List.first()

          audit(:failureMergePDF, %{
            exit_status: "#{error_code}-#{error_msg}",
            filepath: final_path
          })

          :error
      end
    rescue
      error ->
        audit(:failureMergePDF, %{exit_status: error.original, filepath: final_path})
        :error
    end
  end

  defp concatenate_generic_files(file_paths, final_path) do
    file_merger = "#{File.cwd() |> elem(1)}/tools/concat_files.sh"
    args = file_paths ++ [final_path]

    try do
      case System.cmd(file_merger, args,
             env: [
               {"IAC_MERGE_FILES", Application.get_env(:boilerplate, :iac_merge_files)}
             ],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          audit(:successMergePDF, %{})
          :ok

        {output, error_code} ->
          error_msg = output |> String.split("\n") |> List.first()

          audit(:failureMergePDF, %{
            exit_status: "#{error_code}-#{error_msg}",
            filepath: final_path
          })

          :error
      end
    rescue
      error ->
        audit(:failureMergePDF, %{exit_status: error.original, filepath: final_path})
        :error
    end
  end

  # merge uploaded pdf and images files
  defp concat_and_save_files(files, file_type)
       when file_type in [".pdf", ".png", ".gif", ".jpg", ".jpeg", ".hevc", ".heic", ".heif"] do
    {:ok, tmp_final_path} = Briefly.create(prefix: "boilerplate", extname: ".pdf")
    filename = Path.basename(tmp_final_path)

    case concatenate_pdf_files(files, tmp_final_path) do
      :ok -> {:ok, %{path: tmp_final_path, filename: filename}}
      _ -> nil
    end
  end

  # merge files having same file type other than pdf
  defp concat_and_save_files(files, file_type) when file_type != "pdf" do
    {:ok, tmp_final_path} = Briefly.create(prefix: "boilerplate_generic", extname: file_type)
    filename = Path.basename(tmp_final_path)
    IO.inspect(tmp_final_path)

    case concatenate_generic_files(files, tmp_final_path) do
      :ok -> {:ok, %{path: tmp_final_path, filename: filename}}
      _ -> nil
    end
  end

  def merge_multiple_file_uploads(files) when length(files) > 1 do
    file_with_types =
      files
      |> Enum.map(fn file ->
        file_ext = Path.extname(file.filename)

        case convert_to_pdf(file.path, file.filename, file_ext) do
          {:ok, file_path} -> {:pdf, file_ext, file_path}
          {:error, _err} -> nil
        end
      end)

    # TODO: use propper error handling for image conversion error
    if Enum.member?(file_with_types, nil) do
      nil
    else
      file_type = file_with_types |> List.first() |> elem(1)
      files_to_concat = file_with_types |> Enum.map(fn x -> x |> elem(2) end)

      case concat_and_save_files(files_to_concat, file_type) do
        {:ok, info} -> {:ok, info}
        _ -> nil
      end
    end
  end

  def merge_multiple_file_uploads(files) when length(files) == 1 do
    file = files |> List.first()
    {:ok, %{path: file.path, filename: file.filename}}
  end

  def merge_multiple_file_uploads(files), do: {:ok, files}

  defp concat_str_to_word(word, str) do
    result =
      if str != nil do
        data =
          str
          |> String.replace(" ", "_")
          |> String.replace(".", "")
          |> String.downcase()

        "#{word}-#{data}"
      else
        word
      end

    result
  end

  def clone_request(req_info, params) do
    new = %BoilerPlate.DocumentRequest{
      title: req_info.title,
      packageid: req_info.packageid,
      description: req_info.description,
      attributes: params["attr"],
      # task confirmation file upload
      flags: params["flags"],
      status: params["status"],
      enable_expiration_tracking: req_info.enable_expiration_tracking,
      expiration_info: %{},
      dashboard_order: req_info.dashboard_order
    }

    Repo.insert!(new)
  end

  ###
  ### Internal API
  ###

  def api_document_return(us_user, did, comments, :document) do
    doc = Repo.get(Document, did)
    rd = Repo.get(RawDocument, doc.raw_document_id)
    cs = Document.changeset(doc, %{status: 3, return_comments: comments, flags: 0})

    if BoilerPlate.AccessPolicy.has_admin_access_to?(Repo.get(Company, rd.company_id), us_user) do
      BoilerPlate.Email.send_returned_document_or_request_email(
        rd.name,
        comments,
        Repo.get(Package, Repo.get(PackageAssignment, doc.assignment_id).package_id),
        Repo.get(User, Repo.get(Recipient, doc.recipient_id).user_id),
        us_user
      )

      audit(:review_document_return, %{
        user: us_user,
        company_id: doc.company_id,
        document_id: doc.id,
        raw_document_id: doc.raw_document_id,
        recipient_id: doc.recipient_id,
        return_comments: comments
      })

      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, doc.recipient_id)
      :ok
    else
      audit(:review_document_return_failure, %{
        user: us_user,
        company_id: doc.company_id,
        document_id: doc.id,
        raw_document_id: doc.raw_document_id,
        recipient_id: doc.recipient_id,
        return_comments: comments,
        reason: 2
      })

      :forbidden
    end
  end

  def api_document_return(us_user, did, comments, :request) do
    request_returned = Repo.get(RequestCompletion, did)
    request = Repo.get(DocumentRequest, request_returned.requestid)

    # this denotes the returned request in task confirmation request
    doc =
      if request.flags == 6 do
        assignment = Repo.get(PackageAssignment, request_returned.assignment_id)
        contents = Repo.get(PackageContents, assignment.contents_id)

        new_requests = contents.requests |> Enum.filter(&(&1 != request.id))
        cs = PackageContents.changeset(contents, %{requests: new_requests})
        Repo.update!(cs)

        task_req = Repo.get(DocumentRequest, request_returned.file_request_reference)
        unset_has_upload_cs = DocumentRequest.changeset(task_req, %{has_file_uploads: false})

        Repo.update!(unset_has_upload_cs)

        mark_confirmation_read_cs =
          RequestCompletion.changeset(request_returned, %{status: 4, return_comments: comments})

        Repo.update!(mark_confirmation_read_cs)

        Repo.one(
          from r in RequestCompletion,
            where:
              r.company_id == ^request_returned.company_id and
                r.assignment_id == ^assignment.id and
                r.recipientid == ^contents.recipient_id and
                r.requestid == ^request_returned.file_request_reference,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      else
        request_returned
      end

    cs =
      if doc.status != 5 do
        RequestCompletion.changeset(doc, %{status: 3, return_comments: comments})
      else
        RequestCompletion.changeset(doc, %{status: 7, return_comments: comments})
      end

    company = Repo.get(Company, doc.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      BoilerPlate.Email.send_returned_document_or_request_email(
        request.title,
        comments,
        Repo.get(Package, request.packageid),
        Repo.get(User, Repo.get(Recipient, doc.recipientid).user_id),
        us_user
      )

      audit(:review_request_return, %{
        user: us_user,
        company_id: company.id,
        request_id: doc.requestid,
        request_completion_id: doc.id,
        recipient_id: doc.recipientid,
        return_comments: comments
      })

      Repo.update!(cs)
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, doc.recipientid)

      :ok
    else
      audit(:review_request_return_failure, %{
        user: us_user,
        company_id: company.id,
        request_id: doc.requestid,
        request_completion_id: doc.id,
        recipient_id: doc.recipientid,
        return_comments: comments,
        reason: 2
      })

      :forbidden
    end
  end

  def api_document_approve(requestor, did, export_action) do
    doc = Repo.get(Document, did)
    cs = Document.changeset(doc, %{status: 2})
    rd = Repo.get(RawDocument, doc.raw_document_id)
    company = Repo.get(Company, rd.company_id)

    if requestor != nil and requestor.company_id == company.id do
      audit(:review_document_approve, %{
        user: Repo.get(User, requestor.user_id),
        company_id: company.id,
        document_id: doc.id,
        raw_document_id: doc.raw_document_id,
        recipient_id: doc.recipient_id
      })

      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, doc.recipient_id)

      # Check if we need to send a notification that it was "counter-signed"
      recip = Repo.get(Recipient, doc.recipient_id)

      if rd.editable_during_review do
        recip_user = Repo.get(User, recip.user_id)
        requestor_user = Repo.get(User, requestor.user_id)
        BoilerPlate.Email.send_countersign_completed(recip_user.email, requestor_user, rd, recip)
      end

      sp = StorageProvider.permanent_of(company)

      if export_action == "yes" or (export_action == "default" and sp.auto_export) do
        StorageProvider.put(sp, :document, doc, %{
          full_name: recip.name,
          checklist_name: "WIP"
        })
      end

      :ok
    else
      audit(:review_document_approve_failure, %{
        user: Repo.get(User, requestor.user_id),
        company_id: company.id,
        document_id: doc.id,
        raw_document_id: doc.raw_document_id,
        recipient_id: doc.recipient_id,
        reason: 2
      })

      :forbidden
    end
  end

  def api_request_approve(requestor, did, export_action) do
    doc = Repo.get(RequestCompletion, did)
    company = Repo.get(Company, doc.company_id)

    if requestor != nil and company.id == requestor.company_id do
      # Find all the requestcompletions that are part of this
      get_all_completed_req_for_assignment_query =
        from r in RequestCompletion,
          where:
            r.requestid == ^doc.requestid and
              r.status == ^doc.status and
              r.recipientid == ^doc.recipientid and
              r.company_id == ^doc.company_id,
          select: r

      Repo.transaction(fn ->
        get_all_completed_req_for_assignment_query
        |> Repo.stream()
        |> Stream.map(fn d ->
          cs =
            if d.status != 5 do
              RequestCompletion.changeset(d, %{status: 2})
            else
              RequestCompletion.changeset(d, %{status: 6})
            end

          Repo.update!(cs)

          if d.file_request_reference != nil do
            task_completion =
              Repo.one(
                from r in RequestCompletion,
                  where:
                    r.requestid == ^d.file_request_reference and
                      r.status == 1 and
                      r.recipientid == ^doc.recipientid and
                      r.company_id == ^doc.company_id,
                  order_by: [desc: r.inserted_at],
                  limit: 1,
                  select: r
              )

            # if this is nil, the confirmation file is already accepted
            if task_completion != nil do
              task_cs = RequestCompletion.changeset(task_completion, %{status: 2})
              Repo.update!(task_cs)
            end
          end
        end)
        |> Stream.run()
      end)

      audit(:review_request_approve, %{
        user: Repo.get(User, requestor.user_id),
        company_id: company.id,
        request_id: doc.requestid,
        request_completion_id: doc.id,
        recipient_id: doc.recipientid
      })

      recip = Repo.get(Recipient, doc.recipientid)
      sp = StorageProvider.permanent_of(company)

      if export_action == "yes" or (export_action == "default" and sp.auto_export) do
        StorageProvider.put(sp, :request_completion, doc, %{
          full_name: recip.name,
          checklist_name: "WIP"
        })
      end

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, doc.recipientid)
      :ok
    else
      audit(:review_request_approve_failure, %{
        user: Repo.get(User, requestor.user_id),
        company_id: company.id,
        request_id: doc.requestid,
        request_completion_id: doc.id,
        recipient_id: doc.recipientid,
        reason: 2
      })

      :forbidden
    end
  end

  def api_delete_template(requestor, us_user, tid) do
    tpl = Repo.get(RawDocument, tid)

    if requestor.company_id == tpl.company_id do
      if BoilerPlate.Policy.can_delete?(:template, tpl) do
        audit(:generic_delete_success, %{user: us_user, document_id: tpl.id})
        cs = RawDocument.changeset(tpl, %{flags: tpl.flags ||| 1})
        Repo.update!(cs)

        :ok
      else
        audit(:generic_delete_failure, %{user: us_user, document_id: tpl.id, reason: 1})

        :contained_in_package
      end
    else
      audit(:generic_delete_failure, %{user: us_user, document_id: tpl.id, reason: 2})

      :forbidden
    end
  end

  def api_request_missing(us_user, aid, rid, reason, force) do
    assign = Repo.get(PackageAssignment, aid)
    assign_package = Repo.get(Package, assign.package_id)
    company = Repo.get(Company, assign_package.company_id)

    recipient = Repo.get(Recipient, assign.recipient_id)

    request = Repo.get(DocumentRequest, rid)

    if BoilerPlate.AccessPolicy.has_access_to?(:company, company, us_user) do
      # Supersede all previous uploads in this class
      previous_rcs =
        Repo.all(
          from d in RequestCompletion,
            where: d.requestid == ^request.id and d.assignment_id == ^assign.id,
            select: d
        )

      for req <- previous_rcs do
        Repo.update!(RequestCompletion.changeset(req, %{status: 4}))
      end

      new_status =
        if force do
          6
        else
          5
        end

      rc = %RequestCompletion{
        recipientid: recipient.id,
        file_name: "",
        status: new_status,
        company_id: company.id,
        assignment_id: assign.id,
        requestid: request.id,
        is_missing: true,
        missing_reason: reason,
        flags: 0,
        return_comments: reason
      }

      Repo.insert!(rc)

      audit(:recipient_request_missing, %{
        user: us_user,
        company_id: company.id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        missing_reason: reason
      })

      contents = Repo.get(PackageContents, assign.contents_id)

      if assign_package != nil && Package.check_if_completed_by(assign, recipient) do
        BoilerPlateWeb.UserController.send_package_completed_email(
          contents,
          assign.requestor_id,
          recipient
        )
      end

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      :ok
    else
      audit(:recipient_request_missing_failure, %{
        user: us_user,
        company_id: company.id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        missing_reason: reason,
        reason: 2
      })

      :forbidden
    end
  end

  defp api_get_templates(company, filter_string) do
    case filter_string do
      "labelled" ->
        Repo.all(
          from d in RawDocument,
            join: iac in IACDocument,
            on: iac.document_id == d.id,
            join: imf in IACMasterForm,
            on: iac.master_form_id == imf.id,
            join: iacf in IACField,
            on: fragment("? = ANY (?)", iacf.id, imf.fields),
            distinct: true,
            where:
              iac.document_type == 1 and iacf.label != "" and not is_nil(iacf.label) and
                d.company_id == ^company.id and
                d.is_archived == false,
            select: d
        )

      "none" ->
        Repo.all(
          from d in RawDocument,
            where: d.company_id == ^company.id and d.is_archived == false,
            order_by: d.name,
            select: d
        )
    end
    |> Enum.filter(&(RawDocument.is_hidden?(&1) == false))
    |> Enum.sort_by(&String.downcase(&1.name), :asc)
  end

  def api_put_template_file(_file, _base_doc) do
    raise ArgumentError, message: "api_put_template_file is deprecated, use api_replace_template"
  end

  def api_put_template_details(params, base_doc) do
    base_flags = base_doc.flags &&& ~~~10

    incoming_doc = %{
      name: params["name"],
      description: params["description"],
      editable_during_review: params["allow_edits"],
      file_retention_period: params["file_retention_period"],
      tags: params["tags"],
      flags:
        cond do
          params["is_rspec"] -> base_flags ||| 2
          params["is_info"] -> base_flags ||| 8
          true -> base_flags
        end
    }

    cs = RawDocument.changeset(base_doc, incoming_doc)
    Repo.update!(cs)

    :ok
  end

  def api_archive_template(requestor, base_doc) do
    if base_doc == nil or requestor == nil or
         requestor.company_id != base_doc.company_id do
      {:err, :forbidden}
    else
      cs =
        RawDocument.changeset(base_doc, %{
          is_archived: not RawDocument.is_template_archived?(base_doc)
        })

      Repo.update!(cs)
      :ok
    end
  end

  def api_substitute_template(base_doc, upl) do
    with {:ok, new_doc} <- copy_template_with_file(base_doc, upl),
         :ok <- replace_template_in_packages(base_doc, new_doc) do
      {:ok, new_doc.id}
    else
      {:err, x} -> {:err, x}
    end
  end


  def api_reset_template(requestor, base_doc, flag) do
    base_doc = %{base_doc | flags: flag}
    IO.inspect(base_doc)
    with {:ok, new_doc} <- duplicate_template(base_doc),
          :ok <- replace_template_in_packages(base_doc, new_doc) do
            api_archive_template(requestor, base_doc)
      {:ok, new_doc.id}
    else
      {:err, x} -> {:err, x}
    end
  end

  ###
  ### Plug handlers
  ###

  def requestor_new_template(conn, params = %{"name" => name, "upload" => upl}) do
    is_archived = params["archive_template"] == "true"
    tags = params["tags"] || []
    version = 1 # for all new templates, version is 1

    # TODO: verify that tags is good?
    # TODO: move this into an api_* call, but for now this seems infallible so idk

    requestor = get_current_requestor(conn)
    type = RawDocument.file_extension_type(Path.extname(upl.filename))
    template_fn = UUID.uuid4() <> Path.extname(upl.filename)

    {_status, final_path} =
      RawDocument.store(%{
        filename: template_fn,
        path: upl.path
      })

    template = %RawDocument{
      name: name,
      description: "-",
      file_name: final_path,
      type: type,
      flags: 0,
      company_id: requestor.company_id,
      is_archived: is_archived,
      tags: tags,
      version: version
    }

    n = Repo.insert!(template)

    json(conn, %{
      id: n.id
    })
  end

  def requestor_update_raw_doc(conn, params) do
    requestor = get_current_requestor(conn)
    updated_name = params["name"]
    base_doc = Repo.get(RawDocument, params["id"])

    cond do
      requestor == nil or base_doc == nil ->
        conn |> put_status(403) |> text("Forbidden")

      requestor.company_id != base_doc.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      updated_name == "" or updated_name == nil or
        String.length(updated_name) <= 0 or String.length(updated_name) >= 255 ->
        conn |> put_status(403) |> text("Invalid Name")

      true ->
        cs = RawDocument.changeset(base_doc, %{name: updated_name})
        Repo.update!(cs)

        text(conn, "OK")
    end
  end

  def requestor_substitute_template(conn, %{"id" => id, "file" => upl}) do
    requestor = get_current_requestor(conn)
    base_doc = Repo.get(RawDocument, id)

    cond do
      requestor == nil or base_doc == nil ->
        conn |> put_status(403) |> text("Forbidden")

      requestor.company_id != base_doc.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        case api_substitute_template(base_doc, upl) do
          {:ok, nid} ->
            json(conn, %{
              id: nid
            })

          {:err, x} ->
            conn |> put_status(400) |> text(x)
        end
    end
  end

  def requestor_template_reset(conn, %{"id" => id, "flag" => flag}) do
    requestor = get_current_requestor(conn)
    base_doc = Repo.get(RawDocument, id)
    IO.inspect(flag)
    new_flag = flag || 0
    IO.inspect(new_flag)
    IO.inspect(base_doc)


    cond do
      requestor == nil or base_doc == nil ->
        conn |> put_status(403) |> text("Forbidden")

      requestor.company_id != base_doc.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        case api_reset_template(requestor, base_doc, new_flag) do
          {:ok, nid} ->
            json(conn, %{
              id: nid
            })

          {:err, x} ->
            conn |> put_status(400) |> text(x)
        end
    end
  end

  def requestor_archive_template(conn, params) do
    requestor = get_current_requestor(conn)
    base_doc = Repo.get(RawDocument, params["id"])

    case api_archive_template(requestor, base_doc) do
      :ok ->
        text(conn, "OK")

      {:err, :forbidden} ->
        conn |> put_status(403) |> text(:forbidden)
    end
  end

  def requestor_put_template(conn, params) do
    requestor = get_current_requestor(conn)
    base_doc = Repo.get(RawDocument, params["id"])

    reply =
      cond do
        requestor == nil or base_doc == nil -> {:err, :forbidden}
        requestor.company_id != base_doc.company_id -> {:err, :forbidden}
        Map.has_key?(params, "file") -> api_put_template_file(params["file"], base_doc)
        true -> api_put_template_details(params, base_doc)
      end

    case reply do
      :ok -> text(conn, "OK")
      {:err, :forbidden} -> conn |> put_status(403) |> text("Forbidden")
      {:err, r} -> conn |> put_status(400) |> text(r)
    end
  end

  def requestor_delete_template(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    reply = conn |> get_current_requestor() |> api_delete_template(us_user, id)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def requestor_template_with_id(conn, %{"id" => id, "type" => type}) do
    # is the api client requestor or the recipient
    us =
      case User.user_type_to_atom(type) do
        :recipient -> get_current_recipient(conn)
        :requestor -> get_current_requestor(conn)
        _ -> nil
      end

    rd = Repo.get(RawDocument, id)

    cond do
      rd == nil or us == nil ->
        conn |> put_status(403) |> text("Forbidden")

      rd.company_id != us.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      true ->
        render(conn, "raw_document.json", raw_document: rd)
    end
  end

  def requestor_templates(conn, params) do
    filter_string = params["filter"] || "none"
    requestor = get_current_requestor(conn)
    company = Repo.get(Company, requestor.company_id)

    render(conn, "raw_documents.json", raw_documents: api_get_templates(company, filter_string))
  end

  ###
  ### Plug handlers: downloads
  ###

  defp stream_download_with_body(conn, body, disp_name) do
    conn
    |> put_resp_header("access-control-expose-headers", "*")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{disp_name}\"")
    |> put_resp_header("x-boilerplate-filename", "#{disp_name}")
    |> resp(200, body)
  end

  defp stream_download_with_zip_body(conn, body, disp_name) do
    conn
    |> put_resp_header("access-control-expose-headers", "*")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{disp_name}\"")
    |> put_resp_header("x-boilerplate-filename", "#{disp_name}")
    |> put_resp_header("content-type", "application/octet-stream")
    |> resp(200, body)
  end

  # NOTE: type is unused but will be used later!
  defp stream_download_s3(_type, conn, file_name, disp_name) do
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    base_path = "uploads"

    body = @storage_mod.download_file_stream(bucket, "#{base_path}/#{file_name}")

    stream_download_with_body(conn, body, disp_name)
  end

  defp download_raw_document(conn, company, doc, recipient) do
    cpn =
      company.name
      |> String.replace(" ", "_")
      |> String.replace(".", "")
      |> String.downcase()

    recipient_name =
      if recipient != nil do
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()
      end

    rcpname = if recipient != nil, do: recipient_name, else: cpn
    status = if recipient != nil, do: "-open-", else: ""

    extname = Path.extname(doc.file_name)
    date = doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")

    disp_name =
      "#{rcpname}-#{doc.name |> String.replace(" ", "_") |> String.downcase()}#{status}#{date}#{extname}"

    stream_download_s3(:raw_document, conn, doc.file_name, disp_name)
  end

  def download_base_iac_doc(conn, %{"tid" => tid}) do
    disp_name = "rest_in_peace_mirci_february_27_2021.pdf"
    iac_doc = Repo.get(IACDocument, tid)

    stream_download_s3(:iac_document, conn, iac_doc.file_name, disp_name)
  end

  def completed_document_download(conn, %{"aid" => aid, "did" => did}) do
    assignment = Repo.get(PackageAssignment, aid)

    repeat_reference_name =
      Repo.get(PackageContents, assignment.contents_id).recipient_description

    doc = Repo.get(Document, did)
    rd = Repo.get(RawDocument, doc.raw_document_id)
    recipient = Repo.get(Recipient, assignment.recipient_id)

    if recipient.id == doc.recipient_id do
      rcpname =
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn =
        rd.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn_repeat_referene = concat_str_to_word(docn, repeat_reference_name)

      date = doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      extname = Path.extname(doc.filename)
      disp_name = "#{rcpname}-#{docn_repeat_referene}-completed-#{date}#{extname}"

      stream_download_s3(:document, conn, doc.filename, disp_name)
    else
      text(conn, "INVALID REQUEST")
    end
  end

  def cabinet_download(conn, %{"uid" => uid, "cid" => cid}) do
    cab = Repo.get(Cabinet, cid)
    recipient = Repo.get(Recipient, uid)
    requestor = get_current_requestor(conn)

    if requestor != nil and requestor.company_id == recipient.company_id and
         recipient.id == cab.recipient_id do
      rcpname =
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn =
        cab.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      date = cab.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      extname = Path.extname(cab.filename)
      disp_name = "#{rcpname}-#{docn}-#{date}#{extname}"

      stream_download_s3(:cabinet, conn, cab.filename, disp_name)
    else
      text(conn, "INVALID REQUEST")
    end
  end

  def assigned_raw_document_download(conn, %{"aid" => aid, "did" => raw_doc_id}) do
    doc = Repo.get(RawDocument, raw_doc_id)
    company = Repo.get(Company, doc.company_id)
    assign = Repo.get(PackageAssignment, aid)
    assign_package = Repo.get(Package, assign.package_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    repeat_reference_name = Repo.get(PackageContents, assign.contents_id).recipient_description
    recipient = Repo.get(Recipient, assign.recipient_id)

    if BoilerPlate.AccessPolicy.can_we_access?(:company, company, conn) and
         assign_package.company_id == recipient.company_id do
      # Record that the document was downloaded
      if assign.docs_downloaded == nil do
        cs = PackageAssignment.changeset(assign, %{docs_downloaded: [doc.id]})
        Repo.update!(cs)
      else
        if doc.id not in assign.docs_downloaded do
          new = (assign.docs_downloaded |> Enum.filter(&(&1 != nil))) ++ [doc.id]
          cs = PackageAssignment.changeset(assign, %{docs_downloaded: new})
          Repo.update!(cs)
        end
      end

      # Check if RSD and if it has an RDC
      doc =
        if doc.type == 0 and RawDocument.is_rspec?(doc) do
          rdc =
            Repo.all(
              from d in RawDocumentCustomized,
                where:
                  d.recipient_id == ^assign.recipient_id and
                    d.contents_id == ^assign.contents_id and
                    d.raw_document_id == ^doc.id,
                order_by: [desc: d.inserted_at],
                select: d
            )
            |> Enum.at(0)

          %{doc | file_name: rdc.file_name}
        else
          doc
        end

      docn_repeat_referene = concat_str_to_word(doc.name, repeat_reference_name)
      doc_with_repeat_reference = %{doc | name: docn_repeat_referene}

      audit(:recipient_document_download, %{
        user: us_user,
        company_id: company.id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        document_id: doc.id
      })

      download_raw_document(conn, company, doc_with_repeat_reference, recipient)
    else
      audit(:recipient_document_download_failure, %{
        user: us_user,
        company_id: company.id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        document_id: doc.id,
        reason: 2
      })

      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def requestor_customized_doc_download(conn, %{"aid" => aid, "did" => customization_id}) do
    rdc = Repo.get(RawDocumentCustomized, customization_id)
    doc = Repo.get(RawDocument, rdc.raw_document_id)
    company = Repo.get(Company, doc.company_id)
    assign = Repo.get(PackageAssignment, aid)
    repeat_reference_name = Repo.get(PackageContents, assign.contents_id).recipient_description

    if BoilerPlate.AccessPolicy.can_we_access?(:company, company, conn) do
      doc = %{doc | file_name: rdc.file_name}
      docn_repeat_referene = concat_str_to_word(doc.name, repeat_reference_name)
      doc_with_repeat_reference = %{doc | name: docn_repeat_referene}

      download_raw_document(conn, company, doc_with_repeat_reference, nil)
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def raw_document_download(conn, %{"did" => did}) do
    doc = Repo.get(RawDocument, did)
    company = Repo.get(Company, doc.company_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if BoilerPlate.AccessPolicy.can_we_admin_company?(conn, company) do
      download_raw_document(conn, company, doc, nil)
    else
      Logger.warn("[uid #{us_user.id}] Forbidden: tried raw_document_download did #{did}")
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def review_document_download(conn, %{"did" => did, "type" => type}) do
    doc = Repo.get(Document, did)
    rd = Repo.get(RawDocument, doc.raw_document_id)
    company = Repo.get(Company, rd.company_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    assignment = Repo.get(PackageAssignment, doc.assignment_id)

    repeat_reference_name =
      Repo.get(PackageContents, assignment.contents_id).recipient_description

    if BoilerPlate.AccessPolicy.can_we_admin_company?(conn, company) do
      recipient = Repo.get(Recipient, doc.recipient_id)

      rcpname =
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn =
        rd.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn_repeat_referene = concat_str_to_word(docn, repeat_reference_name)

      date = doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      extname = Path.extname(doc.filename)
      disp_name = "#{rcpname}-#{docn_repeat_referene}-#{type}-#{date}#{extname}"

      if type == "completed" do
        # Store that we downloaded this document
        cs = Document.changeset(doc, %{flags: 2})
        Repo.update!(cs)
      end

      stream_download_s3(:document, conn, doc.filename, disp_name)
    else
      Logger.warn("[uid #{us_user.id}] Forbidden: tried review_document_download did #{did}")
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def completed_request_download(conn, %{"did" => did, "type" => type, "aid" => aid}) do
    comp = Repo.get(RequestCompletion, did)
    req = Repo.get(DocumentRequest, comp.requestid)
    assignment = Repo.get(PackageAssignment, aid)
    company = Repo.get(Company, comp.company_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = Repo.get(Recipient, comp.recipientid)

    repeat_reference_name =
      Repo.get(PackageContents, assignment.contents_id).recipient_description

    if BoilerPlate.AccessPolicy.can_we_access?(:company, company, conn) and
         assignment.recipient_id == comp.recipientid do
      rcpname =
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn =
        req.title
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn_repeat_referene = concat_str_to_word(docn, repeat_reference_name)

      date = comp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      extname = Path.extname(comp.file_name)
      disp_name = "#{rcpname}-#{docn_repeat_referene}-#{type}-#{date}#{extname}"

      if type == "completed" do
        # Store that we downloaded this document
        cs = RequestCompletion.changeset(comp, %{flags: 2})
        Repo.update!(cs)
      end

      stream_download_s3(:request_completion, conn, comp.file_name, disp_name)
    else
      Logger.warn("[uid #{us_user.id}] Forbidden: tried completed_request_download did #{did}")
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def review_request_download(conn, %{"did" => did, "type" => type}) do
    comp = Repo.get(RequestCompletion, did)
    req = Repo.get(DocumentRequest, comp.requestid)
    company = Repo.get(Company, comp.company_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    assignment = Repo.get(PackageAssignment, comp.assignment_id)

    repeat_reference_name =
      Repo.get(PackageContents, assignment.contents_id).recipient_description

    # both requestor and recipient with access to doc can download it
    if BoilerPlate.AccessPolicy.has_normal_access_to?(company, us_user) do
      if 2 in req.attributes do
        redirect(conn, to: "/review/read/#{comp.id}")
      else
        recipient = Repo.get(Recipient, comp.recipientid)

        rcpname =
          recipient.name
          |> String.replace(" ", "_")
          |> String.replace(".", "")
          |> String.downcase()

        docn =
          req.title
          |> String.replace(" ", "_")
          |> String.replace(".", "")
          |> String.downcase()

        docn_repeat_referene = concat_str_to_word(docn, repeat_reference_name)

        date = comp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
        extname = Path.extname(comp.file_name)
        disp_name = "#{rcpname}-#{docn_repeat_referene}-#{type}-#{date}#{extname}"

        if type == "completed" do
          # Store that we downloaded this document
          cs = RequestCompletion.changeset(comp, %{flags: 2})
          Repo.update!(cs)
        end

        stream_download_s3(:request_completion, conn, comp.file_name, disp_name)
      end
    else
      Logger.warn("[uid #{us_user.id}] Forbidden: tried review_request_download did #{did}")
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def customize_rsd_download(conn, %{"cid" => cid, "rid" => rid, "rsdid" => rsdid}) do
    contents = Repo.get(PackageContents, cid)
    recipient = Repo.get(Recipient, rid)
    rd = Repo.get(RawDocumentCustomized, rsdid)
    raw_doc = Repo.get(RawDocument, rd.raw_document_id)
    company = Repo.get(Company, recipient.company_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    is_valid_download? = contents.id == rd.contents_id

    if BoilerPlate.AccessPolicy.can_we_access?(:company, company, conn) and is_valid_download? do
      rcpname =
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn =
        raw_doc.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()

      docn_repeat_referene = concat_str_to_word(docn, contents.recipient_description)

      extname = Path.extname(rd.file_name)
      disp_name = "#{rcpname}-#{docn_repeat_referene}#{extname}"

      audit(:contents_rsd_download, %{
        user: us_user,
        company_id: company.id,
        recipient_id: recipient.id,
        contents_Id: contents.id,
        document_id: rd.id
      })

      stream_download_s3(:raw_document_customized, conn, rd.file_name, disp_name)
    else
      audit(:contents_rsd_download_failure, %{
        user: us_user,
        company_id: company.id,
        recipient_id: recipient.id,
        contents_id: contents.id,
        document_id: rd.id,
        reason: 2
      })

      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def api_download_completed_checklist(conn, %{"aid" => assignment_id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, assignment_id)
    contents = Repo.get(PackageContents, assignment.contents_id)
    company = Repo.get(Company, assignment.company_id)
    recipient = Repo.get(Recipient, assignment.recipient_id)

    case BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      true ->
          {zip_content, disp_name} = BoilerPlate.ChecklistDownloader.download_completed_checklist(company, assignment, contents, recipient)
          stream_download_with_zip_body(conn, zip_content, disp_name)
      _ -> conn |> put_status(403) |> text("Forbidden")
    end
  end

  def api_download_recipient_checklists(conn, %{"rid" => recipient_id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = Repo.get(Recipient, recipient_id)
    company = Repo.get(Company, us_user.company_id)

    # get all chgecklist for recipient
    all_assignments = Repo.all(
        from pa in PackageAssignment,
          where: pa.recipient_id == ^recipient_id,
          select: pa
        )

    case BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      true ->
          case BoilerPlate.ChecklistDownloader.download_recipient_checklists(company, recipient, all_assignments) do
            {zip_content, disp_name} -> stream_download_with_zip_body(conn, zip_content, disp_name)
            :forbidden -> conn |> put_status(403) |> text("Forbidden")
          end
      _ -> conn |> put_status(403) |> text("Forbidden")
    end
  end

  ###
  ### Plug handlers: Expiration Tracking
  ###

  def add_expiration_info(conn, params = %{"pid" => request_id}) do
    request_info = Repo.get(DocumentRequest, request_id)
    expiration_params = params["expirationInfo"]

    has_confirmation_file_uploaded? = request_info.has_file_uploads

    task_confirmation_upload_doc_id =
      if has_confirmation_file_uploaded? do
        doc =
          Repo.get_by(RequestCompletion, %{
            file_request_reference: request_info.id,
            status: 1
          })

        if doc != nil do
          doc.requestid
        end
      else
        nil
      end

    cs =
      if task_confirmation_upload_doc_id != nil do
        DocumentRequest.changeset(Repo.get(DocumentRequest, task_confirmation_upload_doc_id), %{
          expiration_info: expiration_params,
          enable_expiration_tracking: true
        })
      else
        DocumentRequest.changeset(request_info, %{
          expiration_info: expiration_params,
          enable_expiration_tracking: true
        })
      end

    Repo.update!(cs)

    text(conn, "OK")
  end

  def return_expired_document(conn, %{"id" => request_id, "comments" => comments}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    case api_document_return(us_user, request_id, comments, :request) do
      :ok ->
        request_info = Repo.get(RequestCompletion, request_id)
        cs = RequestCompletion.changeset(request_info, %{is_expired: false})

        Repo.update!(cs)
        text(conn, "OK")

      _ ->
        conn |> put_status(500) |> text("Error")
    end
  end
end
