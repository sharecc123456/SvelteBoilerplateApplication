alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.RawDocument
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Document
alias BoilerPlate.Recipient
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlate.Form
alias BoilerPlate.FormSubmission
alias BoilerPlate.DashboardCache
alias BoilerPlateWeb.ApiController
alias BoilerPlateWeb.FormController
import Ecto.Query
require Logger

defmodule BoilerPlate.FileCleanerUtils do
  def can_delete?(doc_time, file_retention_period) do
    doc_time_utc = DateTime.from_naive!(doc_time, "Etc/UTC")
    current_time = DateTime.utc_now()

    diff = DateTime.diff(current_time, doc_time_utc)

    diff > file_retention_period
  end

  def delete_document_uploads(
        id,
        assignment_id,
        status
      ) do
    all_doc_uploads =
      Repo.all(
        from doc in Document,
          # already deleted
          # manually deleted
          where:
            doc.raw_document_id == ^id and
              doc.status != 9 and
              doc.status != 4 and
              doc.assignment_id == ^assignment_id,
          select: doc
      )

    all_doc_uploads
    |> Enum.each(fn doc_upload ->
      cs = %{
        filename: doc_upload.filename <> ".del",
        status: status
      }

      doc_cs = Document.changeset(doc_upload, cs)
      Repo.update!(doc_cs)
    end)
  end

  def delete_document(
        dr,
        assignment_id,
        company_file_retention_period,
        manual_delete \\ false
      ) do
    # get the document
    doc = Repo.get(RawDocument, dr.id)
    completion_id = dr.completion_id
    file_retention_period = doc.file_retention_period

    last_upload = Repo.get(Document, completion_id)

    retention_period =
      if file_retention_period != nil && file_retention_period > 0 do
        file_retention_period
      else
        company_file_retention_period
      end

    to_delete =
      cond do
        manual_delete -> true
        file_retention_period == -1 -> false
        true -> can_delete?(last_upload.updated_at, retention_period)
      end

    status =
      if manual_delete do
        4
      else
        9
      end

    if to_delete do
      IO.puts("delete all docs for assignment_id: #{assignment_id} doc_id #{dr.id} ")
      delete_document_uploads(dr.id, assignment_id, status)
      true
    else
      false
    end
  end

  def delete_request_uploads(
        id,
        assignment_id,
        status
      ) do
    all_doc_uploads =
      Repo.all(
        from rc in RequestCompletion,
          # already deleted
          # manually deleted
          where:
            rc.requestid == ^id and
              rc.status != 9 and
              rc.status != 4 and
              rc.assignment_id == ^assignment_id,
          select: rc
      )

    all_doc_uploads
    |> Enum.each(fn doc_upload ->
      cs = %{
        file_name: doc_upload.file_name <> ".del",
        status: status
      }

      doc_cs = RequestCompletion.changeset(doc_upload, cs)
      Repo.update!(doc_cs)
    end)
  end

  def delete_request(
        fr,
        assignment_id,
        company_file_retention_period,
        manual_delete \\ false
      ) do
    # get the document
    doc = Repo.get(DocumentRequest, fr.id)
    completion_id = fr.completion_id
    file_retention_period = doc.file_retention_period
    last_upload = Repo.get(RequestCompletion, completion_id)

    # check if its set not to be deleted
    retention_period =
      if file_retention_period != nil && file_retention_period > 0 do
        file_retention_period
      else
        company_file_retention_period
      end

    to_delete =
      cond do
        manual_delete -> true
        file_retention_period == -1 -> false
        true -> can_delete?(last_upload.updated_at, retention_period)
      end

    status =
      if manual_delete do
        4
      else
        9
      end

    if to_delete do
      IO.puts("delete all requests assignment_id: #{assignment_id} req_id: #{fr.id}")
      delete_request_uploads(fr.id, assignment_id, status)
      true
    else
      false
    end
  end

  def delete_form(
        form_data,
        company_file_retention_period,
        manual_delete \\ false
      ) do
    if form_data.is_submitted or manual_delete do
      form = Repo.get(Form, form_data.id)
      submission_id = form_data.submission_id
      form_submission = Repo.get(FormSubmission, form_data.submission_id)
      file_retention_period = form.file_retention_period
      old_status = form_data.state.status

      retention_period =
        if file_retention_period != nil && file_retention_period > 0 do
          file_retention_period
        else
          company_file_retention_period
        end

      to_delete =
        cond do
          manual_delete -> true
          file_retention_period == -1 -> false
          true -> can_delete?(form_submission.updated_at, retention_period)
        end

      if to_delete do
        if old_status != 4 do
          if old_status == 9 and old_status == 10 do
            # already deleted
            true
          else
            # Item still in progress, definitely manual_delete
            new_status = 4

            if submission_id != 0 do
              FormController.delete_form_submission(submission_id, new_status)
            end

            true
          end
        else
          new_status =
            if manual_delete do
              4
            else
              9
            end

          FormController.delete_form_submission(submission_id, new_status)
          true
        end
      else
        false
      end
    else
      # nothing to delete bro
      true
    end
  end

  def delete_assignment_uploads(
        assignment,
        company,
        manual_delete \\ false
      ) do
    assignment_id = assignment.id
    document_requests = assignment.document_requests
    file_requests = assignment.file_requests
    forms = assignment.forms
    # check if all the elements have been deleted

    all_docs_deleted =
      document_requests
      |> Enum.all?(fn doc ->
        doc
        |> delete_document(
          assignment_id,
          company.file_retention_period,
          manual_delete
        )
      end)

    # check if all the elements have been deleted
    all_requests_deleted =
      file_requests
      |> Enum.all?(fn fr ->
        fr
        |> delete_request(
          assignment_id,
          company.file_retention_period,
          manual_delete
        )
      end)

    all_forms_deleted =
      forms
      |> Enum.all?(fn form ->
        form
        |> delete_form(
          company.file_retention_period,
          manual_delete
        )
      end)

    all_deleted = all_docs_deleted && all_requests_deleted && all_forms_deleted

    IO.puts(
      "DELSTAT: c_id: #{company.id}, a_id: #{assignment_id}, deleted: #{all_deleted}, docs: #{all_docs_deleted}, reqs: #{all_requests_deleted}, forms: #{all_forms_deleted}"
    )

    if all_deleted do
      IO.puts("Deleting the company_id: #{company.id} and assignment_id #{assignment_id}")
      assignment = Repo.get(PackageAssignment, assignment_id)
      Repo.update(PackageAssignment.changeset(assignment, %{status: 2}))
    end

    DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
  end

  def delete_assignments_for_company(company) do
    IO.puts("Checking files to delete for company_id #{company.id}")

    params = %{
      "filterStr" => [%{"apiKey" => "checkliststatus", "value" => ["4"]}]
    }

    assignments =
      ApiController.get_assignments_for_company(
        company,
        params,
        false
      )

    IO.puts(
      "company_id: #{company.id} Total completed assignments found: #{Enum.count(assignments)}"
    )

    assignments
    |> Enum.each(fn asmt ->
      asmt.checklists
      |> Enum.each(fn cl ->
        cl |> delete_assignment_uploads(company)
      end)
    end)
  end

  def delete_assignment_files(id) do
    assignment = Repo.get(PackageAssignment, id)
    recipient = Repo.get(Recipient, assignment.recipient_id)
    company = Repo.get(Company, assignment.company_id)
    [assignment_data] = ApiController.do_make_assignments_of_requestor([assignment], recipient)
    manual_delete = true

    assignment_data |> delete_assignment_uploads(company, manual_delete)
  end

  def auto_deletion_for_companies do
    companies =
      Repo.all(
        from c in Company,
          select: c
      )

    companies
    |> Enum.filter(&(&1.file_retention_period != -1))
    |> Enum.each(fn company ->
      {_, pid} =
        Task.start(fn ->
          delete_assignments_for_company(company)
        end)

      IO.puts("Deletion Task created for company_id: #{company.id} with pid: #{inspect(pid)}")
    end)
  end
end
