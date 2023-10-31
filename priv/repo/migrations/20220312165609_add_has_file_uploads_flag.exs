defmodule BoilerPlate.Repo.Migrations.AddHasFileUploadsFlag do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :has_file_uploads, :boolean, default: false
    end
  end
end
