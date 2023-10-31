alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.Recipient
alias BoilerPlate.FilterEngine
alias BoilerPlate.QueryEngine
import Ecto.Query
require Logger

defmodule BoilerPlateWeb.FilterDashboardController do
  use BoilerPlateWeb, :controller

  def requestor_dashboard(conn, params) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    filter_params = params["filterStr"]
    where_clause = FilterEngine.filter_where(params["filterStr"])

    all_active_assignments =
      PackageAssignment
      |> where([pa], pa.company_id == ^company.id and pa.status == 0)
      |> join(:inner, [pa], r in Recipient,
        as: :recp,
        on: pa.recipient_id == r.id and r.show_in_dashboard == true
      )
      |> QueryEngine.build_join_clause(filter_params)
      |> where(^where_clause)
      |> Repo.all()
      |> Enum.group_by(fn pa -> pa.recipient_id end)

    IO.inspect(all_active_assignments)

    json(
      conn,
      "all_active_assignments"
    )
  end
end
