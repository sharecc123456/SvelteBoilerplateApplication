alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.Requestor
alias BoilerPlate.Company
import Ecto.Query

defmodule BoilerPlateWeb.InternalView do
  use BoilerPlateWeb, :view

  defp get_admin_emails(c) do
    requestors =
      Repo.all(from r in Requestor, where: r.company_id == ^c.id and r.status == 0, select: r)

    requestors
    |> Enum.map(&Repo.get(User, &1.user_id))
    |> Enum.filter(&(&1 != nil))
    |> Enum.map_join(" ", & &1.email)
  end
end
