defmodule BoilerPlate.Repo.Migrations.CreatePaymentPlans do
  use Ecto.Migration

  def up do
    create table(:payment_plans) do
      add :name, :string
      add :base_cost, :integer
      add :charge_frequency, :integer
      add :status, :integer
      add :flags, :integer
      add :display_name, :string
      add :seats, :integer

      timestamps()
    end

    flush()

    BoilerPlate.Repo.insert!(%BoilerPlate.PaymentPlan{
      name: "basic",
      display_name: "Basic",
      base_cost: 999,
      charge_frequency: 30,
      seats: 1,
      status: 0,
      flags: 0
    })

    BoilerPlate.Repo.insert!(%BoilerPlate.PaymentPlan{
      name: "pro",
      display_name: "Professional",
      base_cost: 2499,
      charge_frequency: 30,
      seats: 2,
      status: 0,
      flags: 0
    })
  end

  def down do
    drop table(:payment_plans)
  end
end
