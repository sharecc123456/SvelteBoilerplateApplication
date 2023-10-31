defmodule BoilerPlate.TrialChecker do
  use GenServer
  require Logger
  import Ecto.Query
  alias BoilerPlate.Repo
  alias BoilerPlate.Company

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    Process.send_after(self(), :check_payments, 5 * 1000)

    Process.register(self(), :bp_payments)

    {:ok, state}
  end

  def handle_info(:check_payments, state) do
    Logger.info "Checking payments"

    send self(), :check_trials
    send self(), :check_due_payments

    Process.send_after(self(), :check_payments, 24 * 60 * 60 * 1000)
    {:noreply, state}
  end

  def handle_info(:check_trials, state) do
    Logger.info "Checking if any trials have expired"

    companies_expiring_today = Repo.all(from c in Company, where: c.trial_end < ^Date.utc_today(), select: c)
    for company <- companies_expiring_today do
      Logger.info "[trial_checker] #{company.name} trial expired BUT IGNORED"

      # TODO: send an email

      #cs = Company.changeset(company, %{coupon: 0, trial_end: nil, status: Company.atom_to_status(:free_trial_expired)})
      #Repo.update!(cs)
    end

    {:noreply, state}
  end

  def handle_info(:check_due_payments, state) do
    Logger.info "Checking if any payments are due"

    {:noreply, state}
  end
end
