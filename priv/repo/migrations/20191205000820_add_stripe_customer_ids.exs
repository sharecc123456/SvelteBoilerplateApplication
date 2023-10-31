defmodule BoilerPlate.Repo.Migrations.AddStripeCustomerIds do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_customer_id, :string
    end
  end
end
