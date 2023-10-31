defmodule BoilerPlate.Repo.Migrations.CreateRequestCompletions do
  use Ecto.Migration

  def change do
    create table(:request_completions) do
      add :requestid, :integer
      add :recipientid, :integer
      add :file_name, :string

      timestamps()
    end

  end
end
