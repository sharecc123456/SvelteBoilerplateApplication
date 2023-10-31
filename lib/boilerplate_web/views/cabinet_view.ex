defmodule BoilerPlateWeb.CabinetView do
  use BoilerPlateWeb, :view

  def render("cabinet.json", %{cabinet: cabinet}) do
    %{
      id: cabinet.id,
      name: cabinet.name,
      file_name: cabinet.filename,
      description: "",
      # Manually added
      status: %{
        status: 4,
        date: cabinet.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
        type: :manually_added
      },
      inserted_at: cabinet.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
    }
  end

  def render("cabinets.json", %{cabinets: cabs}) do
    render_many(cabs, BoilerPlateWeb.CabinetView, "cabinet.json", as: :cabinet)
  end
end
