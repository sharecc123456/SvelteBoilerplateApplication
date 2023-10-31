defmodule BoilerPlate.Repo.Migrations.AddAllowMutlpleReqSubPackageTable do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :allow_duplicate_submission, :boolean, default: false
      add :allow_multiple_requests, :boolean, default: false
    end
  end
end
