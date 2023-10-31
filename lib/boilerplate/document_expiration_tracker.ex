defmodule BoilerPlate.ExpirationTracker do
  @moduledoc "ExpirationTracker GenServer - handles tracking expirations, notifications, emails async"
  use GenServer
  require Logger
  alias BoilerPlate.Repo
  alias BoilerPlate.PackageAssignment
  alias BoilerPlate.PackageContents
  alias BoilerPlate.User
  alias BoilerPlate.Company
  alias BoilerPlate.DocumentRequest
  alias BoilerPlate.RequestCompletion
  alias BoilerPlate.Recipient
  alias BoilerPlate.Requestor
  alias BoilerPlate.DataManipulationUtils
  import Ecto.Query

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_) do
    schedule_worker()
    {:ok, %{}}
  end

  def handle_info(:worker, state) do
    Logger.info("Initializing document expiration tracker ...")
    expiration_tracker()
    Logger.info("[ExpirationTracker]: schedule job ...")
    schedule_worker()
    Logger.info("[ExpirationTracker]: job complete ...")
    {:noreply, state}
  end

  def expiration_tracker() do
    utc_date_today = Timex.today()
    documents_to_track = get_expiring_documents()
    # IO.inspect(documents_to_track, label: "documents_to_track ...")
    handle_expiring_documents(documents_to_track, utc_date_today)
  end

  defp get_expiring_documents() do
    Logger.info("[ExpirationTracker]: Fetching Expiring documents ...")

    Repo.all(
      from r in RequestCompletion,
        join: dr in DocumentRequest,
        on: dr.id == r.requestid and r.is_expired == false,
        where: r.status != 0 and dr.enable_expiration_tracking == true,
        order_by: r.inserted_at,
        select: %{
          id: dr.id,
          completion_id: r.id,
          expiration_info: dr.expiration_info,
          assignment_id: r.assignment_id,
          document_title: dr.title
        }
    )
    |> Enum.filter(&(&1.expiration_info["type"] == "date"))
    |> Enum.map(&make_email_content(&1))
  end

  defp handle_expiring_documents(documents_to_track, utc_date_today) do
    Logger.info("[ExpirationTracker]: Handling Expiring documents ...")
    # next_week_expiring
    next_week_expiring =
      documents_to_track
      |> Enum.filter(
        &(NaiveDateTime.to_date(Timex.shift(&1.expiring_date, weeks: -1)) == utc_date_today)
      )

    Logger.info("[ExpirationTracker]: Handling next week expiring documents ...")

    next_week_expiring
    |> Enum.each(fn x ->
      BoilerPlate.Email.send_document_expire_email(x, :one_week)
      add_expiration_info_notification(:expiring_next_week, x)
    end)

    next_month_expiring =
      documents_to_track
      |> Enum.filter(
        &(NaiveDateTime.to_date(Timex.shift(&1.expiring_date, months: -1)) == utc_date_today)
      )

    Logger.info("[ExpirationTracker]: Handling next month expiring documents ...")

    next_month_expiring
    |> Enum.each(fn x ->
      BoilerPlate.Email.send_document_expire_email(x, :one_month)
      add_expiration_info_notification(:expiring_next_month, x)
    end)

    # expiring_today
    expiring_today =
      documents_to_track
      |> Enum.filter(&(NaiveDateTime.to_date(&1.expiring_date) == utc_date_today))

    expiring_today
    |> Enum.each(fn x ->
      BoilerPlate.Email.send_document_expire_email(x, :expired)
      flag_expired_document(x)
      add_expiration_info_notification(:expired, x)
    end)
  end

  defp flag_expired_document(doc) do
    req_comp = Repo.get(RequestCompletion, doc.completion_id)

    cs = BoilerPlate.RequestCompletion.changeset(req_comp, %{is_expired: true})
    Repo.update!(cs)
  end

  defp add_expiration_info_notification(expiration_type, doc) do
    Logger.info("[ExpirationTracker]: adding notification ...")
    req_comp = Repo.get(RequestCompletion, doc.completion_id)
    assignment = Repo.get(PackageAssignment, req_comp.assignment_id)
    contents = Repo.get(PackageContents, assignment.contents_id)
    requestor_user = Repo.get(User, Repo.get(Requestor, assignment.requestor_id).user_id)
    recipient_user = Repo.get(User, Repo.get(Recipient, assignment.recipient_id).user_id)

    doc_params = %{
      due_date: doc.expiring_date,
      assignment_id: req_comp.assignment_id,
      request_id: req_comp.requestid,
      document_id: req_comp.id,
      document_type: "request",
      checklist_name: contents.title
    }

    BoilerPlateWeb.NotificationController.add_document_expired_notification(
      expiration_type,
      req_comp.company_id,
      doc_params,
      requestor_user,
      recipient_user
    )
  end

  defp make_email_content(doc) do
    assignment = Repo.get(PackageAssignment, doc.assignment_id)
    contents = Repo.get(PackageContents, assignment.contents_id)
    company = Repo.get(Company, assignment.company_id)
    requestor_user = Repo.get(User, Repo.get(Requestor, assignment.requestor_id).user_id)
    recipient_user = Repo.get(User, Repo.get(Recipient, assignment.recipient_id).user_id)

    updated_map = %{
      checklist: %{title: contents.title},
      requestor: %{email: requestor_user.email, name: recipient_user.name},
      recipient: %{email: recipient_user.email, name: requestor_user.name},
      company: %{name: company.name},
      expiring_date: Timex.parse(doc.expiration_info["value"], "{YYYY}-{0M}-{0D}") |> elem(1)
    }

    Map.merge(doc, updated_map)
  end

  defp schedule_worker() do
    # each day at midnight
    next_run_delay = DataManipulationUtils.calculate_next_cycle_delay(Timex.now())

    BoilerPlateAssist.SendAfter.send_after(
      "Document Expiration Checker",
      self(),
      :worker,
      next_run_delay
    )

    # Process.send_after(self(), :worker, next_run_delay)
  end
end
