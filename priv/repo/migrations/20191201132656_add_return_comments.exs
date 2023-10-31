defmodule BoilerPlate.Repo.Migrations.AddReturnComments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :return_comments, :string
    end
  end
end
