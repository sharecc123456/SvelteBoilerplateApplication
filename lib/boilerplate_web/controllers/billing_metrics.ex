alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.Company
alias BoilerPlate.IACSignature
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Recipient
alias BoilerPlateWeb.FormController
alias BoilerPlateWeb.PackageController
use Timex

defmodule BoilerPlate.CustomDateTimex do
  @moduledoc """
    This is a datetime with timezone calculations module
  """

  @doc """
    get timezone specific datetime string format

    Returns {:ok, "2022-01-15T07:51:39.464545-06:00"}
  """
  def get_datetime_str_timezone(timezone_str) do
    Timex.now(timezone_str) |> Timex.format("{ISO:Extended}")
  end

  @doc """
    get utc time

  Returns `<DateTime(2016-02-29T12:30:30.120+00:00Z Etc/UTC)>`
  """
  def get_datetime(), do: Timex.now()

  @doc """
     adjusts the date using various units: duration, microseconds, seconds, minutes, hours, days, weeks, months, years.

  Returns `<DateTime()>`
  """
  def subtract_dates(:week, date, shift_by), do: Timex.shift(date, weeks: shift_by)
  def subtract_dates(:day, date, shift_by), do: Timex.shift(date, days: shift_by)
  def subtract_dates(:month, date, shift_by), do: Timex.shift(date, months: shift_by)
  def subtract_dates(:minute, date, shift_by), do: Timex.shift(date, minutes: shift_by)

  @doc """
      date truncate current month
    Returns `<DateTime()>`
  """
  def get_current_month_date(date) do
    date |> Timex.beginning_of_month()
  end

  @doc """
      date truncate current year
    Returns `<DateTime()>`
  """
  def get_current_year_date(date) do
    date |> Timex.beginning_of_year()
  end

  def get_last_month_start_date(date) do
    subtract_dates(:month, date, -1) |> Timex.beginning_of_month()
  end

  def get_last_month_end_date(date) do
    start_month_date = get_current_month_date(date)
    # with timezone
    subtract_dates(:minute, start_month_date, -1)
  end

  def get_epoch_time(), do: DateTime.from_unix!(0)

  def get_current_quarter(date) do
    Timex.beginning_of_quarter(date)
  end

  def parse_date_from_str(time_str, format \\ "%Y-%m-%d"),
    do: Timex.parse!(time_str, format, :strftime)
end

defmodule BoilerPlateWeb.BillingMetrics do
  use BoilerPlateWeb, :controller

  @total_metrics_calc_field [
    "rspec_documents_processed",
    "signature_processed",
    "forms_processed",
    "task_completed",
    "data_inputs",
    "files_uploaded",
    "generic_documents_processed"
  ]

  def get_user_billing_metrics_per_period(company_id, user_ids, start_date, end_date) do
    %{
      active_recipients:
        Recipient.get_company_recipients_count_by_period(
          company_id,
          start_date,
          end_date
        ),
      deleted_recipients:
        Recipient.get_company_deleted_recipients_count_by_period(
          company_id,
          start_date,
          end_date
        ),
      checklists_sent:
        PackageAssignment.get_company_assignments_count_by_period(
          company_id,
          start_date,
          end_date
        ),
      rspec_documents_processed:
        PackageAssignment.get_company_documents_count_by_period(
          :rspec,
          company_id,
          start_date,
          end_date
        ),
      generic_documents_processed:
        PackageAssignment.get_company_documents_count_by_period(
          :generic,
          company_id,
          start_date,
          end_date
        ),
      files_uploaded:
        PackageController.get_company_file_uploads_count_by_period(
          company_id,
          start_date,
          end_date,
          "files"
        ),
      data_inputs:
        PackageController.get_company_file_uploads_count_by_period(
          company_id,
          start_date,
          end_date,
          "data"
        ),
      task_completed:
        PackageController.get_company_file_uploads_count_by_period(
          company_id,
          start_date,
          end_date,
          "task"
        ),
      signature_processed:
        IACSignature.count_total_signatures_for_company_by_period(
          user_ids,
          start_date,
          end_date
        ),
      forms_processed:
        FormController.get_processed_forms_for_company(
          company_id,
          start_date,
          end_date
        ),
      forms_answered:
        FormController.get_total_questions_answered_for_company(
          company_id,
          start_date,
          end_date
        )
    }
  end

  def calculate_total_metrics_processed(data) do
    metric_total =
      data
      |> Enum.reduce(0, fn {metrics, value}, acc ->
        if Atom.to_string(metrics) in @total_metrics_calc_field do
          acc + value
        else
          acc
        end
      end)

    total_recipients = data.active_recipients + data.deleted_recipients

    %{total: metric_total, total_recipients: total_recipients}
  end

  def calculate_billing_metrics(:week, company_id, user_ids, utc_time_today) do
    date = BoilerPlate.CustomDateTimex.subtract_dates(:week, utc_time_today, -1)

    data = get_user_billing_metrics_per_period(company_id, user_ids, date, utc_time_today)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:current_month, company_id, user_ids, utc_time_today) do
    date = BoilerPlate.CustomDateTimex.get_current_month_date(utc_time_today)

    data = get_user_billing_metrics_per_period(company_id, user_ids, date, utc_time_today)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:current_year, company_id, user_ids, utc_time_today) do
    date = BoilerPlate.CustomDateTimex.get_current_year_date(utc_time_today)

    data = get_user_billing_metrics_per_period(company_id, user_ids, date, utc_time_today)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:last_month, company_id, user_ids, utc_time_today) do
    start_date = BoilerPlate.CustomDateTimex.get_last_month_start_date(utc_time_today)
    end_date = BoilerPlate.CustomDateTimex.get_last_month_end_date(utc_time_today)

    data = get_user_billing_metrics_per_period(company_id, user_ids, start_date, end_date)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:lifetime, company_id, user_ids, utc_time_today) do
    epoch_time = BoilerPlate.CustomDateTimex.get_epoch_time()

    data = get_user_billing_metrics_per_period(company_id, user_ids, epoch_time, utc_time_today)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:current_quarter, company_id, user_ids, utc_time_today) do
    start_date = BoilerPlate.CustomDateTimex.get_current_quarter(utc_time_today)

    data = get_user_billing_metrics_per_period(company_id, user_ids, start_date, utc_time_today)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(:last_quarter, company_id, user_ids, utc_time_today) do
    current_quarter = BoilerPlate.CustomDateTimex.get_current_quarter(utc_time_today)
    start_date = BoilerPlate.CustomDateTimex.subtract_dates(:month, current_quarter, -3)

    data = get_user_billing_metrics_per_period(company_id, user_ids, start_date, current_quarter)
    total = calculate_total_metrics_processed(data)
    Map.merge(data, total)
  end

  def calculate_billing_metrics(_, _company_id, _user_ids, _utc_time_today) do
    raise "No metrics Type"
    nil
  end

  def users_billing_metrics(conn, %{"id" => company_id}) do
    company = Repo.get(Company, company_id)

    if company != nil and BoilerPlate.AccessPolicy.can_we_admin_company?(conn, company) do
      utc_time_today = BoilerPlate.CustomDateTimex.get_datetime()
      all_associated_user_ids = User.all_associated_with(company) |> Enum.map(& &1.id)

      json(conn, %{
        week:
          calculate_billing_metrics(:week, company_id, all_associated_user_ids, utc_time_today),
        current_month:
          calculate_billing_metrics(
            :current_month,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        current_year:
          calculate_billing_metrics(
            :current_year,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        last_month:
          calculate_billing_metrics(
            :last_month,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        current_quarter:
          calculate_billing_metrics(
            :current_quarter,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        last_quarter:
          calculate_billing_metrics(
            :last_quarter,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        lifetime:
          calculate_billing_metrics(
            :lifetime,
            company_id,
            all_associated_user_ids,
            utc_time_today
          ),
        file_retention_period: company.file_retention_period
      })
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def set_file_retention(conn, params) do
    file_retention_period = params["file_retention_period"]
    company_id = params["company_id"]

    requestor = get_current_requestor(conn)

    if requestor.company_id != company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      company = Repo.get(Company, company_id)

      changeset = %{
        file_retention_period: file_retention_period
      }

      cs = Company.changeset(company, changeset)
      Repo.update!(cs)
      json(conn, %{msg: "ok"})
    end
  end
end
