defmodule BoilerPlate.PaymentCoupon do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payment_coupons" do
    field :flags, :integer
    field :name, :string
    field :status, :integer
    field :type, :integer
    field :value, :string

    timestamps()
  end

  @doc false
  def changeset(payment_coupons, attrs) do
    payment_coupons
    |> cast(attrs, [:type, :value, :name, :status, :flags])
    |> validate_required([:type, :value, :name, :status, :flags])
  end
end
