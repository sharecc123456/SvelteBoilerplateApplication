defmodule BoilerPlate.Requestor do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "requestors" do
    field :company_id, :integer
    field :terms_accepted, :boolean, default: false
    field :user_id, :integer
    field :status, :integer
    field :name, :string
    field :organization, :string
    field :esign_consented, :boolean, default: false
    field :esign_consent_date, :utc_datetime
    field :esign_consent_remote_ip, :string, default: "none"
    field :esign_saved_signature, :string, default: ""
    field :notify_admins, :boolean, default: false
    field :weekly_digest, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(requestor, attrs) do
    requestor
    |> cast(attrs, [
      :user_id,
      :company_id,
      :terms_accepted,
      :status,
      :name,
      :organization,
      :esign_consented,
      :esign_consent_date,
      :esign_consent_remote_ip,
      :esign_saved_signature,
      :notify_admins,
      :weekly_digest
    ])
    |> validate_required([
      :user_id,
      :company_id,
      :terms_accepted,
      :status,
      :name,
      :organization,
      :esign_consented
    ])
  end

  def all_active_for(company) do
    BoilerPlate.Repo.all(
      from u in BoilerPlate.User,
        join: r in BoilerPlate.Requestor,
        on: r.user_id == u.id,
        select: r,
        where:
          r.company_id == ^company.id and
            r.status == 0
    )
  end
end
