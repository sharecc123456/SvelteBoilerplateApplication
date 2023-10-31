defmodule BoilerPlate.Repo.Migrations.AddPhoneNumberColumn do
  use Ecto.Migration

  def change do
    alter table(:recipients) do
      add :phone_number, :string, default: ""
    end
  end
end
