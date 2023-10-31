defmodule BoilerPlate.Repo.Migrations.AddUsersTermsCheck do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :terms_accepted, :boolean
    end
  end
end
