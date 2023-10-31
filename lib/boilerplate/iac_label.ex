defmodule BoilerPlate.IACLabel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iac_label" do
    field :flags, :integer
    field :status, :integer
    field :value, :string
    field :question, :string, default: nil
    field :company_id, :id
    field :inserted_by, :id

    timestamps()
  end

  @doc false
  def changeset(iac_label, attrs) do
    iac_label
    |> cast(attrs, [:value, :status, :flags, :question, :company_id, :inserted_by])
    |> validate_required([:value, :status, :flags])
  end
end
