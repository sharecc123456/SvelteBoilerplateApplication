defmodule BoilerPlate.Repo.Migrations.AddCompanyIdsToRequestCompletions do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :company_id, :integer
    end
  end
end
