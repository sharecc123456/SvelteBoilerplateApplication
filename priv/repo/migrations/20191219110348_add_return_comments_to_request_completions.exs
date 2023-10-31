defmodule BoilerPlate.Repo.Migrations.AddReturnCommentsToRequestCompletions do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :return_comments, :string
    end
  end
end
