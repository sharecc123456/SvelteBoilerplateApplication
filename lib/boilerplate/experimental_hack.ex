defmodule BoilerPlate.ExperimentalHack do
  use Ecto.Schema
  import Ecto.Changeset

  schema "experimental_hacks" do
    field :ticket_id, :integer
    field :data, :string

    timestamps()
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:ticket_id, :data])
    |> validate_required([:ticket_id, :data])
  end
end
