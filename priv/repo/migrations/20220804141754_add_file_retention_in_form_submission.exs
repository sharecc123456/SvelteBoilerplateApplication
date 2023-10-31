defmodule BoilerPlate.Repo.Migrations.AddFileRetentionFormSubmission do
  use Ecto.Migration

  def change do
    # file_retention_period
    # nil -> not set
    # -1 -> infinite/forever
    # val > 0 -> finite
    alter table(:forms) do
      add :file_retention_period, :integer, default: nil
    end
  end
end
