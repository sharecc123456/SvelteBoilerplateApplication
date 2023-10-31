defmodule BoilerPlate.PaymentPlan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payment_plans" do
    field :base_cost, :integer
    field :charge_frequency, :integer
    field :seats, :integer
    field :flags, :integer
    field :name, :string
    field :display_name, :string
    field :status, :integer

    timestamps()
  end

  @doc false
  def changeset(payment_plan, attrs) do
    payment_plan
    |> cast(attrs, [:name, :base_cost, :charge_frequency, :status, :flags, :display_name, :seats])
    |> validate_required([:name, :base_cost, :charge_frequency, :status, :flags, :display_name, :seats])
  end
end
