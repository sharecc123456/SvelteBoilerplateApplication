defmodule BoilerPlate.Cabinet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cabinet" do
    field :name, :string
    field :recipient_id, :integer
    field :requestor_id, :integer
    field :company_id, :integer
    field :filename, :string
    field :status, :integer
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(cabinet, attrs) do
    cabinet
    |> cast(attrs, [:name, :recipient_id, :requestor_id, :company_id, :status, :flags, :filename])
    |> validate_required([:name, :recipient_id, :requestor_id, :company_id, :filename])
  end

  def status_to_atom(status) do
    case status do
      0 -> :ok
      1 -> :deleted
      _ -> :bugged
    end
  end
end
