defmodule BoilerPlate.Repo.Migrations.AddStripeToCompany do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add :stripe_customer_id, :string
      add :plan, :string
      add :coupon, :integer
      add :trial_end, :date
      add :trial_max_packages, :integer
      add :next_payment_due, :date
    end

    flush()

    BoilerPlate.Repo.update_all(BoilerPlate.Company, set: [plan: "time_saver", coupon: 0])
  end

  def down do
    alter table(:companies) do
      remove :stripe_customer_id
      remove :plan
      remove :coupon
      remove :trial_end
      remove :trial_max_packages
      remove :next_payment_due
    end
  end
end
