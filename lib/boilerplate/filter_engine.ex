alias BoilerPlate.User
alias BoilerPlate.Company

defmodule BoilerPlate.FilterUtils do
  @filter_list ["company", "email", "fromDate", "organization"]

  def get_ordered_filter_list, do: @filter_list

  def column_table_mapper(column_name) do
    case column_name do
      "email" -> :users
      "company" -> :company
      "organization" -> :organization
      "fromDate" -> :inserted_at
      _ -> :unknown
    end
  end
end

defmodule BoilerPlate.FilterEngine do
  import Ecto.Query

  defp filter(:users, dynamic, "email", value) do
    dynamic([users: u], ^dynamic and u.email in ^value)
  end

  defp filter(:company, dynamic, "company", value) do
    dynamic([company: c], ^dynamic and c.name in ^value)
  end

  defp filter(:organization, dynamic, "organization", value) do
    dynamic([recp: r], ^dynamic and r.organization in ^value)
  end

  defp filter(:inserted_at, dynamic, "fromDate", value) do
    {:ok, date_obj} = value |> List.first() |> Timex.parse("{YYYY}-{0M}-{0D}")
    {:ok, from_date} = DateTime.from_naive(date_obj, "Etc/UTC")
    dynamic([pa], ^dynamic and pa.inserted_at >= ^from_date)
  end

  defp filter(_unknown, dynamic, _, _), do: dynamic

  def filter_where(params) do
    Enum.reduce(params, dynamic(true), fn param, dynamic ->
      table_atom = BoilerPlate.FilterUtils.column_table_mapper(param["apiKey"])
      filter(table_atom, dynamic, param["apiKey"], param["value"])
    end)
  end
end

defmodule BoilerPlate.QueryEngine do
  import Ecto.Query

  defp join_clause(:users, query, "email", _value) do
    if has_named_binding?(query, :recp) do
      query
      |> join(:inner, [pa, r], u in User, as: :users, on: r.user_id == u.id)
    else
      query
    end
  end

  defp join_clause(:company, query, "company", _value) do
    if has_named_binding?(query, :recp) do
      query
      |> join(:inner, [r], c in Company, as: :company, on: c.id == r.company_id)
    else
      query
    end
  end

  defp join_clause(:unknown, query, _, _), do: query
  defp join_clause(_, query, _, _), do: query

  def build_join_clause(query, params) do
    Enum.reduce(params, query, fn param, query ->
      table_atom = BoilerPlate.FilterUtils.column_table_mapper(param["apiKey"])
      join_clause(table_atom, query, param["apiKey"], param["value"])
    end)
  end
end
