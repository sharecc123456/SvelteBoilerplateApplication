alias BoilerPlate.Repo
alias BoilerPlate.RequestCompletion
alias BoilerPlate.CustomDateTimex
alias BoilerPlateWeb.UserController
alias BoilerPlate.User
alias BoilerPlate.Recipient
alias BoilerPlate.Company
import Ecto.Query
require Logger

defmodule BoilerplateCronjobs.RequestSubmission do
  def work do
    Logger.info("Running RequestSubmission cron job")
    now = CustomDateTimex.get_datetime()
    # Auto submit all request last updated 2 hours ago.
    sub = CustomDateTimex.subtract_dates(:minute, now, -120)

    get_all_companies()
      |> Enum.each(&(auto_submit_requests_for_company(&1, sub)))

  end

  def get_all_companies() do
    # run cron for only paid companies
    Repo.all(from com in Company, where: com.status == 2, select: com.id)
  end

  def auto_submit_requests_for_company(company_id, date_filter) do
    pending_requests_query =
      from rcom in RequestCompletion,
      where: rcom.status == 0 and rcom.updated_at < ^date_filter and rcom.company_id == ^company_id,
      select: rcom

    Repo.transaction(fn ->
      pending_requests_query
        |> Repo.stream()
        |> Stream.each(
          fn p_req ->
            recipient_user = Repo.get(User, Repo.get(Recipient, p_req.recipientid).user_id)
            UserController.api_submit_uploaded_user_request(
              recipient_user,
              p_req.recipientid,
              p_req.id,
              p_req.requestid
            )
            Logger.info("Completed RequestSubmission cron job for #{p_req.id}")
          end
        )
        |> Stream.run()
    end)
  end
end
