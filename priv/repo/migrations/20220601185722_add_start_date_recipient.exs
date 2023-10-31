defmodule BoilerPlate.Repo.Migrations.AddStartDateRecipient do
  use Ecto.Migration

  def change do
    alter table("recipients") do
      add :start_date, :utc_datetime
    end
  end
end
