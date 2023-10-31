alias BoilerPlate.Repo
alias BoilerPlate.IACDocument
alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized
alias BoilerPlate.Document
alias BoilerPlate.Requestor
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlate.EnumTypes
alias BoilerPlate.FormSubmission
alias BoilerPlate.User
alias BoilerPlate.Recipient
alias BoilerPlate.RecipientTag
import Ecto.Query
import Bitwise
require Logger

defmodule BoilerPlate.AssignmentUtils do
  def filter_open_status_additional_file_req(ch) do
    req = ch.file_requests |> Enum.filter(&(&1.flags != 4))
    new_req = req ++ ch.document_requests

    if Enum.count(new_req) > 0 do
      true
    else
      false
    end
  end


  def requestor_assignment_status(dr, fr, forms) do
    new_fr = fr |> Enum.filter(&(&1.flags != 4))
    statuses = (dr ++ new_fr ++ forms) |> Enum.map(& &1.state.status)

    cond do
      # Deleted manually & Automatically
      Enum.all?(statuses, &(&1 == 10)) -> EnumTypes.RequestorChecklistStatus.ManualDeleted.value
      # Deleted Automatically
      Enum.all?(statuses, &(&1 == 9 || &1 == 10)) -> EnumTypes.RequestorChecklistStatus.ManualDeleted.value
      # open checklist extra file
      Enum.any?(statuses, &(&1 == 2 || &1 == 5)) -> EnumTypes.RequestorChecklistStatus.Review.value
      Enum.all?(fr, &(&1.flags == 4)) and (Enum.empty?(dr) and Enum.empty?(forms)) -> EnumTypes.RequestorChecklistStatus.Open.value
      Enum.all?(statuses, &(&1 == 9)) -> EnumTypes.RequestorChecklistStatus.AutoDeleted.value
      Enum.all?(statuses, &(&1 == 4 || &1 == 6 || &1 == 9 || &1 == 10)) -> EnumTypes.RequestorChecklistStatus.Completed.value
      # partially completed docs
      Enum.any?(statuses, &(&1 == 4 || &1 == 6)) -> EnumTypes.RequestorChecklistStatus.PartiallyCompleted.value
      Enum.any?(statuses, &(&1 == 3)) -> EnumTypes.RequestorChecklistStatus.Returned.value
      Enum.all?(statuses, &(&1 == 2 || &1 == 5)) -> EnumTypes.RequestorChecklistStatus.Review.value # this should be in-review status
      Enum.any?(statuses, &(&1 == 1)) -> EnumTypes.RequestorChecklistStatus.Progress.value
      True -> EnumTypes.RequestorChecklistStatus.Open.value
    end
  end

  def iac_setup_for_customization?(rdc) do
    if rdc == nil do
      false
    else
      IACDocument.setup_for?(:raw_document_customized, rdc)
    end
  end

  def get_value_of(request, assignment, recipient) do
    x = get_uploaded(:file_request, request, assignment, recipient)

    if x == nil do
      ""
    else
      x.file_name
    end
  end

  def get_uploaded(:document_request, doc, assignment, recipient) do
    q =
      from d in Document,
        where:
          d.assignment_id == ^assignment.id and
            d.raw_document_id == ^doc.id and
            d.recipient_id == ^recipient.id,
        order_by: [desc: d.id],
        limit: 1,
        select: d

    Repo.one(q)
  end

  def get_uploaded(:file_request, request, assignment, recipient) do
    q =
      from d in RequestCompletion,
        where:
          d.status != 8 and
            d.assignment_id == ^assignment.id and
            d.requestid == ^request.id and
            d.recipientid == ^recipient.id,
        order_by: [desc: d.id],
        limit: 1,
        select: d

    Repo.one(q)
  end

  def status_obj_for(a, doc, assignment, recipient) do
    a
    |> get_uploaded(doc, assignment, recipient)
    |> make_status_obj(a, assignment, doc)
  end

  def make_status_obj(docup, _a, assignment, _doc) do
    cond do
      docup != nil and docup.status == 1 ->
        %{
          # Submitted in recipient portal
          status: EnumTypes.DashboardStatus.Review.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 2 ->
        %{
          # Submitted
          status: EnumTypes.DashboardStatus.Completed.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 6 ->
        %{
          # Missing (approved)
          status: EnumTypes.DashboardStatus.MissingApproved.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 5 ->
        %{
          # Missing
          status: EnumTypes.DashboardStatus.Missing.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 9 ->
        %{
          # deleted automatically
          status: EnumTypes.DashboardStatus.AutoDeleted.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 4 ->
        # deleted manually
        %{
          # uploaded
          status: EnumTypes.DashboardStatus.ManualDeleted.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil and docup.status == 0 ->
        %{
          # uploaded
          status: EnumTypes.DashboardStatus.Progress.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      docup != nil ->
        %{
          # returned
          status: EnumTypes.DashboardStatus.Returned.value,
          flags: docup.flags,
          date: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: docup.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: docup.updated_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }

      True ->
        %{
          # new
          status: EnumTypes.DashboardStatus.Open.value,
          flags: 0,
          date: assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          time: assignment.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          date_time_data: assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
        }
    end
  end

  def get_last_request(assign, recipient, doc) do
    Repo.one(
      from d in RequestCompletion,
        where:
          d.status != 8 and
            d.requestid == ^doc.id and
            d.assignment_id == ^assign.id and
            d.recipientid == ^recipient.id,
        order_by: [desc: d.inserted_at],
        limit: 1,
        select: d
    )
  end

  def get_last_doc(assign, recipient, doc) do
    rid = doc.id
    uid = recipient.id

    Repo.one(
      from d in Document,
        where:
          d.recipient_id == ^uid and
            d.assignment_id == ^assign.id and
            d.raw_document_id == ^rid and
            d.status != 4,
        order_by: [desc: d.inserted_at],
        limit: 1,
        select: d
    )
  end

  def get_latest_activity_info(assignment) do
    last_rc =
      Repo.one(
        from d in RequestCompletion,
          where: d.assignment_id == ^assignment.id,
          order_by: [desc: d.updated_at],
          limit: 1,
          select: d
      )

    last_doc =
      Repo.one(
        from d in Document,
          where: d.assignment_id == ^assignment.id,
          order_by: [desc: d.updated_at],
          limit: 1,
          select: d
      )

    last_form =
      Repo.one(
        from fs in FormSubmission,
          where: fs.contents_id == ^assignment.contents_id,
          order_by: [desc: fs.updated_at],
          limit: 1,
          select: fs
      )

    last_form =
      if last_form == nil do
        nil
      else
        Map.put_new(last_form, :flags, nil)
      end

    if last_rc == nil and last_doc == nil and last_form == nil do
      make_status_obj(nil, nil, assignment, nil)
    else
      uploaded_req = [last_rc, last_doc, last_form] |> Enum.filter(& &1 != nil)

      if uploaded_req == [] do
        make_status_obj(nil, nil, assignment, nil)
      else
        last_req =
          uploaded_req
            |> Enum.sort(& NaiveDateTime.compare(&1.updated_at, &2.updated_at) != :lt)
            |> List.first
        make_status_obj(last_req, nil, assignment, nil)
      end
    end
  end

  def last_updated_time(assignment) do
    get_latest_activity_info(assignment) |> Map.fetch!(:date_time_data)
  end

  def assignment_date(s, assignment) do
    case s do
      0 -> assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      9 -> assignment.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      10 -> assignment.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      _ -> last_updated_time(assignment)
    end
  end

  defp get_assignment_due_date(assignment) do
    if assignment.enforce_due_date == true and assignment.due_date != nil do
      %{
        date: assignment.due_date |> Timex.format!("{YYYY}-{0M}-{0D}")
      }
    else
      %{}
    end
  end

  def build_assignment_response(
         contents,
         assignment,
         pkg,
         _requestor,
         a_status,
         document_requests,
         file_requests,
         forms,
         meta_data \\ %{}
       ) do
    due_date = get_assignment_due_date(assignment)

    metadata =
      if due_date != %{} do
        meta_data |> Map.put(:nearest_due_date, due_date.date)
      else
        %{}
      end

    recipient = Repo.get(Recipient, assignment.recipient_id)
    recipient_user = Repo.get(User, recipient.user_id)

    # added this bit for handling requestor = nil error
    requestor = Repo.get(Requestor, assignment.requestor_id)
    requestor_user = Repo.get(User, requestor.user_id)
    tags = Repo.all(from r in RecipientTag, where: r.id in ^contents.tags, select: r)

    %{
      name: contents.title,
      package_id: contents.package_id,
      contents_id: contents.id,
      id: assignment.id,
      flags: assignment.flags,
      recipient_id: assignment.recipient_id,
      subject: contents.description,
      recipient_reference: contents.recipient_description,
      requestor_reference: contents.req_checklist_identifier,
      sender: %{
        name: requestor.name,
        organization: requestor.organization,
        user_id: requestor.user_id,
        email: requestor_user.email
      },
      recipient_data: %{
        name: recipient.name,
        organization: recipient.organization,
        user_id: recipient_user.id,
        email: recipient_user.email
      },
      state: %{
        status: a_status,
        is_expired: assignment.due_date_expired,
        date: assignment_date(a_status, assignment),
        latest_activity_info: get_latest_activity_info(assignment),
        delivery_fault: assignment.delivery_fault
      },
      last_updated: last_updated_time(assignment),
      due_date: due_date,
      received_date: %{
        date: assignment.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}"),
        time: assignment.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
      },
      ses_state: BoilerPlateWeb.IACController.ses_get_struct(:contents, contents.id),
      document_requests: document_requests,
      file_requests: file_requests,
      allow_duplicate_submission: contents.allow_duplicate_submission,
      allow_multiple_requests: pkg.allow_multiple_requests,
      forms: forms,
      next_event_metadata: metadata,
      last_reminder_info: assignment.reminder_state,
      tags: BoilerPlateWeb.DocumentTagView.render("recipient_tags.json", recipient_tags: tags)
    }
  end

  def assignment_status(dr, fr, forms) do
    new_fr = fr |> Enum.filter(&(&1.flags != 4))
    statuses = (dr ++ new_fr ++ forms) |> Enum.map(& &1.state.status)

    cond do
      # open checklist extra file
      Enum.all?(fr, &(&1.flags == 4)) and Enum.empty?(dr) and Enum.empty?(forms) -> EnumTypes.ChecklistStatus.Open.value
      Enum.all?(statuses, &(&1 == 2 || &1 == 4 || &1 == 6 || &1 == 5)) -> EnumTypes.ChecklistStatus.Completed.value
      # partially completed docs
      Enum.any?(statuses, &(&1 == 4 || &1 == 6)) -> EnumTypes.ChecklistStatus.PartiallyCompleted.value
      Enum.any?(statuses, &(&1 == 3)) -> EnumTypes.ChecklistStatus.Returned.value
      Enum.all?(statuses, &(&1 == 2 || &1 == 5)) -> EnumTypes.ChecklistStatus.Submitted.value
      Enum.any?(statuses, &(&1 == 2 || &1 == 5)) -> EnumTypes.ChecklistStatus.Progress.value
      Enum.any?(statuses, &(&1 == 1)) -> EnumTypes.ChecklistStatus.Progress.value
      True -> EnumTypes.ChecklistStatus.Open.value
    end
  end

  def make_tag_values(doc) do
    if doc.tags != nil do
      all_tags = Repo.all(from r in BoilerPlate.DocumentTag, where: r.id in ^doc.tags, select: r)
      %{
        id: doc.tags,
        values: all_tags |> Enum.map(& %{id: &1.id, name: &1.name, flags: &1.sensitive_level})
      }
    else
      []
    end
  end

  def get_checklist_file_requests(assignment, recipient, contents) do
    request_query =
      from p in DocumentRequest,
        where: p.id in ^contents.requests,
        select: p

    {:ok, file_requests} =
      Repo.transaction(fn ->
        request_query
        |> Repo.stream()
        |> Stream.map(fn req ->
          doc_submitted = get_last_request(assignment, recipient, req)
          has_confirmation_file_uploaded? = req.has_file_uploads

          task_confirmation_upload_doc_id =
            if has_confirmation_file_uploaded? do
              doc =
                Repo.one(
                  from r in RequestCompletion,
                    where: r.file_request_reference == ^req.id,
                    order_by: [desc: r.inserted_at],
                    limit: 1,
                    select: r
                )

              if doc != nil do
                doc.id
              end
            else
              nil
            end

                %{
                  id: req.id,
                  name: req.title,
                  type:
                    if 2 in req.attributes do
                      "data"
                    else
                      if 1 in req.attributes do
                        "task"
                      else
                        "file"
                      end
                    end,
                  flags: req.flags,
                  is_manually_submitted: doc_submitted && (doc_submitted.flags &&& 4) == 4,
                  completion_id:
                    if doc_submitted == nil do
                      0
                    else
                      doc_submitted.id
                    end,
                  state: status_obj_for(:file_request, req, assignment, recipient),
                  file_names: [],
                  value: get_value_of(req, assignment, recipient),
                  required: true,
                  instructions: "Please locate & upload.",
                  inserted_at: req.inserted_at,
                  return_comments:
                    if doc_submitted && doc_submitted.return_comments do
                      doc_submitted.return_comments
                    else
                      nil
                    end,
                  missing_reason:
                    if doc_submitted && doc_submitted.missing_reason do
                      doc_submitted.missing_reason
                    else
                      nil
                    end,
                  description: req.description,
                  link: req.link,
                  has_confirmation_file_uploaded: has_confirmation_file_uploaded?,
                  task_confirmation_file_id: task_confirmation_upload_doc_id,
                  dashboard_order: req.dashboard_order,
                  has_expired:
                    if doc_submitted != nil do
                      doc_submitted.is_expired
                    else
                      false
                    end,
                  expiration_info: req.expiration_info,
                  allow_edit_expiration: req.enable_expiration_tracking,
                  file_retention_period: req.file_retention_period,
                  is_confirmation_required: req.is_confirmation_required
                }
              end
            )
          # changes stream data to list
          |> Enum.to_list()
        end
      )

    file_requests |> Enum.sort_by(&{&1.dashboard_order, &1.name})
  end

  def get_checklist_document_requests(assignment, recipient, contents) do
    doc_query =
      from p in RawDocument,
        where: p.id in ^contents.documents,
        select: p

    {:ok, doc_requests} =
      Repo.transaction(fn ->
        doc_query
        |> Repo.stream()
        |> Stream.map(fn doc ->
          doc_submitted = get_last_doc(assignment, recipient, doc)
          is_rspec? = RawDocument.is_rspec?(doc)

          rdc =
            if is_rspec? do
              Repo.one(
                from r in RawDocumentCustomized,
                  where:
                    r.contents_id == ^contents.id and r.recipient_id == ^assignment.recipient_id and
                      r.raw_document_id == ^doc.id,
                  order_by: [desc: r.inserted_at],
                  limit: 1,
                  select: r
              )
            else
              nil
            end

          iac_doc =
            if is_rspec? and iac_setup_for_customization?(rdc) do
              IACDocument.get_for(:raw_document_customized, rdc)
            else
              IACDocument.get_for(:raw_document, doc)
            end

          is_iac? = iac_doc != nil

          tags = make_tag_values(doc)

          %{
            id: doc.id,
            name: doc.name,
            is_iac: iac_doc != nil,
            # direclty check rdc
            customization:
              if rdc != nil do
                %{customization_id: rdc.id}
              else
                %{}
              end,
            iac_document_id:
              if is_iac? do
                iac_doc.id
              else
                0
              end,
            is_rspec: is_rspec?,
            is_info: RawDocument.is_info?(doc),
            is_manually_submitted: doc_submitted && (doc_submitted.flags &&& 4) == 4,
            base_filename: doc.file_name,
            completion_id:
              if doc_submitted == nil do
                0
              else
                doc_submitted.id
              end,
            state: status_obj_for(:document_request, doc, assignment, recipient),
            description: doc.description,
            instruction:
              if RawDocument.is_info?(doc) do
                "Please press View to look at this document."
              else
                "Please fill out and upload."
              end,
            required: true,
            inserted_at: doc.inserted_at,
            return_comments:
              if doc_submitted && doc_submitted.return_comments do
                doc_submitted.return_comments
              else
                nil
              end,
            file_retention_period: doc.file_retention_period,
            tags: tags,
            document_history:
              if rdc != nil do
                RawDocumentCustomized.get_document_history(doc.id, contents.id, recipient.id)
              else
                []
              end
          }
        end)
        # changes stream data to list
        |> Enum.to_list()
      end)
    doc_requests
  end

  def deleted_checklist_request_status(document_requests, file_requests, forms) do
    document_requests =
      document_requests
      |> Enum.map(fn doc ->
        if doc.state.status != 9 do
          new_state = %{
            date: doc.state.date,
            flags: doc.state.flags,
            status: 10,
            time: doc.state.time
          }

          doc |> Map.put(:state, new_state)
        else
          doc
        end
      end)

    file_requests =
      file_requests
      |> Enum.map(fn file ->
        if file.state.status != 9 do
          new_state = %{
            date: file.state.date,
            flags: file.state.flags,
            status: 10,
            time: file.state.time
          }

          file |> Map.put(:state, new_state)
        else
          file
        end
      end)

    forms =
      forms
      |> Enum.map(fn form ->
        if form.state.status != 9 do
          new_state = %{
            date: form.state.date,
            status: 10,
            time: form.state.time
          }

          form |> Map.put(:state, new_state)
        else
          form
        end
      end)

    [document_requests, file_requests, forms]
  end

  defp get_min_expiration_date_for_checklist(checklist) do
    checklist.file_requests
    |> Enum.filter(&(&1.expiration_info != %{} and &1.expiration_info["type"] == "date"))
    |> Enum.map(& &1.expiration_info["value"])
    |> Enum.min(fn -> :no_expiration end)
  end

  def calculate_nearest_expiration_date(assignments) when is_list(assignments) do
    assignments
    |> Enum.map(fn assignment ->
      get_min_expiration_date_for_checklist(assignment)
    end)
    |> Enum.filter(&(&1 != :no_expiration))
    |> Enum.min(fn -> nil end)
  end

  def calculate_nearest_expiration_date(assignment) do
    data = get_min_expiration_date_for_checklist(assignment)

    if data == :no_expiration do
      nil
    else
      data
    end
  end
end
