defmodule BoilerPlate.Repo.Migrations.AddRequestorChecklistIdPkgContents do
  use Ecto.Migration

  def change do
    alter table(:package_contents) do
      add :req_checklist_identifier, :string, default: ""
    end
  end
end

