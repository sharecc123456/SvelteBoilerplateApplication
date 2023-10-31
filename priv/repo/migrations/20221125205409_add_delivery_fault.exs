defmodule BoilerPlate.Repo.Migrations.AddDeliveryFault do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :delivery_fault, :boolean, default: false
      add :fault_message, :string, default: nil
    end
  end
end
