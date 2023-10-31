defmodule BoilerPlate.Repo.Migrations.TrackDownloadsOnDocumentsAndRequests do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :docs_downloaded, {:array, :integer}
    end
  end
end
