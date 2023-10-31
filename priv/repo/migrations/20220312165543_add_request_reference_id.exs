defmodule BoilerPlate.Repo.Migrations.AddRequestReferenceId do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :file_request_reference, :integer, default: nil
    end
  end
end
