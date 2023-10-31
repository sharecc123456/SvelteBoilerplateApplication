defmodule BoilerPlate.Repo.Migrations.AddCouponToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :coupon, :integer, default: 0
    end
  end
end
