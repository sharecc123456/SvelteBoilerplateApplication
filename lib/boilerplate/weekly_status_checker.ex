defmodule BoilerPlate.WeeklyStatusChecker do
  use GenServer
  alias BoilerPlate.Repo
  alias BoilerPlate.PackageAssignment
  alias BoilerPlate.User
  alias BoilerPlate.Requestor
  alias BoilerPlate.RequestCompletion
  alias BoilerPlate.Company
  import Ecto.Query
  require Logger

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    utc_date_today = Timex.today()
    days_till = Timex.days_to_beginning_of_week(utc_date_today, :sun)
    schedule_work(days_till)
    {:ok, state}
  end

  def handle_info(:work, state) do
    Logger.info("Initiating Weekly Status Check")
    utc_date_today = Timex.today()
    # Is Today Sunday
    days_till = Timex.days_to_beginning_of_week(utc_date_today, :sun)

    case days_till do
      0 ->
        # Reschedule once more
        schedule_work(7)
        create_weekly_status()

      _ ->
        # Reschedule once more
        schedule_work(days_till)
    end

    Logger.info("Completed Weekly Status Update")
    {:noreply, state}
  end

  def schedule_work(_days_till) do
    # Ticket 10406: Now running with Quantum
    # 4. Ensure check for later Date
    # next_run_delay = DataManipulationUtils.calculate_millisec_till_day(days_till)

    # BoilerPlateAssist.SendAfter.send_after("Weekly Digest", self(), :work, next_run_delay)
    # Process.send_after(self(), :work, next_run_delay)
  end

  def handle_weekly_status_email(user, metrics, review_count) do
    # 3. Send email / Make sure there are items
    should_send =
      (metrics.active_recipients >= 1 or
         metrics.checklists_sent >= 1 or
         metrics.rspec_documents_processed >= 1 or
         metrics.generic_documents_processed >= 1 or
         metrics.signature_processed >= 1 or
         metrics.files_uploaded >= 1 or
         metrics.data_inputs >= 1 or
         metrics.task_completed >= 1 or
         review_count >= 1) and FunWithFlags.enabled?(:weekly_digest)

    if should_send do
      BoilerPlate.Email.send_weekly_status_email(user, metrics, review_count)
      Logger.info("Sent weekly status update for user: #{user.name} [#{user.id}]")
    else
      Logger.info("No items to send for user: #{user.name} [#{user.id}]")
    end
  end

  def call_from_cron() do
    create_weekly_status(nil)
  end

  def create_weekly_status(user_specified \\ nil) do
    # 1. Get all the active Requestors (or singular in test case)
    active_requestors =
      if user_specified == nil do
        Repo.all(
          from r in Requestor,
            join: c in Company,
            on: r.company_id == c.id,
            where: r.status == 0 and r.weekly_digest == true,
            select: r
        )
      else
        [Repo.get(Requestor, user_specified)]
      end

    for active_requestor <- active_requestors do
      user = Repo.get(User, active_requestor.user_id)
      company = Repo.get(Company, active_requestor.company_id)
      all_associated_user_ids = User.all_associated_with(company) |> Enum.map(& &1.id)
      utc_time_today = BoilerPlate.CustomDateTimex.get_datetime()

      # 2. Collect Weekly Metrics AND Reviews Count
      weekly_billing_metrics =
        BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
          :week,
          active_requestor.company_id,
          all_associated_user_ids,
          utc_time_today
        )

      IO.inspect(weekly_billing_metrics)

      pending_fr_reviews_query =
        from r in RequestCompletion,
          where:
            r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
              r.assignment_id in subquery(
                from pa in PackageAssignment,
                  where: pa.company_id == ^company.id and pa.status == 0,
                  select: pa.id
              ),
          select: r.id

      pending_fr_reviews_count = BoilerPlate.Repo.aggregate(pending_fr_reviews_query, :count, :id)

      # 3. Send email
      handle_weekly_status_email(
        user,
        weekly_billing_metrics,
        pending_fr_reviews_count
      )
    end
  end
end
