import Ecto.Query

defmodule BoilerPlate.Repo.Migrations.AddDuplicateSubmissionContents do
  use Ecto.Migration

  def up do
    alter table(:package_contents) do
      add :allow_duplicate_submission, :boolean, default: false
    end

    flush()

    from(pc in "package_contents",
      join: pkg in "packages",
      on: pc.package_id == pkg.id,
      update: [set: [allow_duplicate_submission: pkg.allow_duplicate_submission]]
      )
    |> BoilerPlate.Repo.update_all([])
  end

  def down do
    alter table(:package_contents) do
      remove :allow_duplicate_submission
    end

    flush()
  end
end
