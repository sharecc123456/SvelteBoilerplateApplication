defmodule BoilerPlateWeb.IronforgeController do
  use BoilerPlateWeb, :controller

  defp html_page(_), do: "base.html"

  # Requestor side
  defp ironforge_render(conn, page, params) do
    conn
    |> put_layout({BoilerPlateWeb.LayoutView, "ironforge.html"})
    |> put_view(BoilerPlateWeb.IronforgeView)
    |> render(html_page(page),
      params: params,
      ironforge_role: page
    )
  end

  def requestorchoice(conn, _params), do: ironforge_render(conn, :requestor_choose, %{})

  def requestor_side(conn, _params),
    do: ironforge_render(conn, :requestor, %{test_text: "Requestor"})
end
