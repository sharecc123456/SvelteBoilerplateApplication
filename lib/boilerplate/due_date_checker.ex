defmodule BoilerPlate.DueDateChecker do
  use GenServer
  alias BoilerPlate.Repo
  alias BoilerPlate.PackageAssignment
  alias BoilerPlate.User
  alias BoilerPlate.Requestor
  alias BoilerPlate.Recipient
  alias BoilerPlate.PackageContents
  alias BoilerPlate.Company
  alias BoilerPlate.Package
  alias BoilerPlate.DataManipulationUtils
  alias BoilerPlate.CustomDateTimex
  import Ecto.Query
  require Logger

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    # Schedule work to be performed at some point
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, state) do
    Logger.info("Initiating due date check")
    # 1. get all the in progress assignments with due dates
    inprogress_enforced_assignments =
      Repo.all(
        from pa in PackageAssignment,
          where: pa.enforce_due_date == true and pa.status == 0 and pa.due_date_expired == false,
          select: pa
      )
      |> Enum.filter(fn assign -> Package.check_if_assignment_in_progess?(assign) end)

    for assign <- inprogress_enforced_assignments do
      recipient = Repo.get(Recipient, assign.recipient_id)
      user = Repo.get(User, recipient.user_id)
      requestor_user = Repo.get(User, Repo.get(Requestor, assign.requestor_id).user_id)

      try do
        calculate_due_date_expiration(assign, user, requestor_user, Timex.today())
      rescue
        e ->
          # continue on error
          IO.inspect(e, pretty: true, label: "Error Due Date checker")

          Logger.error(
            "Due date checker failed for assignment id
              #{assign.id} of company #{assign.company_id} send by requestor #{assign.requestor_id} to recipient #{assign.recipient_id}"
          )
      end
    end

    # Reschedule once more
    schedule_work()
    Logger.info("Completed due date check")
    {:noreply, state}
  end

  defp schedule_work() do
    next_run_delay = DataManipulationUtils.calculate_next_cycle_delay(Timex.now())
    # Process.send_after(self(), :work, next_run_delay)
    BoilerPlateAssist.SendAfter.send_after("Due Date Checker", self(), :work, next_run_delay)
  end

  def calculate_due_date_expiration(checklist, user, requestor_user, utc_date_today) do
    due_date = NaiveDateTime.to_date(checklist.due_date)

    cond do
      Timex.compare(due_date, utc_date_today, :day) == -1 ->
        Logger.info("Due Date: date after due date ...")
        handle_user_expired_assignment(checklist, user, requestor_user, due_date)

      due_date == utc_date_today ->
        Logger.info("Due Date: Today ...")
        handle_user_remind_assignment(checklist, user, requestor_user, due_date)

      Timex.shift(due_date, weeks: -1) == utc_date_today ->
        Logger.info("Due Date: One week before due date ...")
        handle_user_remind_assignment(checklist, user, requestor_user, due_date)

      Timex.shift(due_date, weeks: -2) == utc_date_today ->
        Logger.info("Due Date: Two weeks before the due date ...")
        handle_user_remind_assignment(checklist, user, requestor_user, due_date)

      true ->
        Logger.info("Due Date: None ...")
    end
  end

  defp handle_user_expired_assignment(assign, user, requestor_user, due_date) do
    # send email
    contents = Repo.get(PackageContents, assign.contents_id)
    company = Repo.get(Company, assign.company_id)

    BoilerPlate.Email.send_assignment_expire_email_to_recipient(
      user,
      requestor_user,
      contents,
      company,
      due_date
    )

    Logger.info("Send expired checklist email - Assignment #{assign.id} ...")

    # update expiring due
    Repo.update(PackageAssignment.changeset(assign, %{due_date_expired: true}))
  end

  defp handle_user_remind_assignment(assign, user, requestor_user, due_date) do
    # send email
    contents = Repo.get(PackageContents, assign.contents_id)
    company = Repo.get(Company, assign.company_id)

    BoilerPlate.Email.send_assignment_remind_email_to_recipient(
      user,
      requestor_user,
      contents,
      company,
      due_date
    )

    update_assignment_reminder_info(assign)
    Logger.info("Send reminder checklist email - Assignment #{assign.id} ...")
  end

  defp update_assignment_reminder_info(assignment) do
    cs =
      PackageAssignment.changeset(assignment, %{
        reminder_state: %{
          send_by: "System (due date)",
          total_count: assignment.reminder_state["total_count"] + 1,
          last_send_at: CustomDateTimex.get_datetime()
        }
      })

    Repo.update!(cs)
  end
end
