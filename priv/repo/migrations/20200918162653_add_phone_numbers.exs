defmodule BoilerPlate.Repo.Migrations.AddPhoneNumbers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :phone_number, :string, default: ""
    end
  end
end
