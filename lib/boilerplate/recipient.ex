alias BoilerPlate.PackageAssignment

defmodule BoilerPlate.Recipient do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type id :: integer
  @type t :: %__MODULE__{
          company_id: integer(),
          organization: String.t(),
          terms_accepted: boolean(),
          user_id: integer(),
          status: integer(),
          name: String.t(),
          esign_consented: boolean(),
          esign_consent_date: DateTime.t(),
          esign_consent_remote_ip: String.t(),
          esign_saved_signature: String.t(),
          show_in_dashboard: boolean(),
          phone_number: String.t(),
          start_date: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "recipients" do
    field :company_id, :integer
    field :organization, :string
    field :terms_accepted, :boolean, default: false
    field :user_id, :integer
    # status bit 0 -> active
    # status bit 1 -> delete
    # status bit 2 -> archive
    field :status, :integer
    field :name, :string
    field :esign_consented, :boolean, default: false
    field :esign_consent_date, :utc_datetime
    field :esign_consent_remote_ip, :string, default: "none"
    field :esign_saved_signature, :string, default: ""
    field :show_in_dashboard, :boolean, default: true
    field :phone_number, :string, default: ""
    field :start_date, :utc_datetime
    field :tags, {:array, :integer}, default: []
    timestamps()
  end

  @doc false
  def changeset(recipient, attrs) do
    recipient
    |> cast(attrs, [
      :organization,
      :user_id,
      :company_id,
      :terms_accepted,
      :status,
      :name,
      :esign_consented,
      :esign_consent_date,
      :esign_consent_remote_ip,
      :esign_saved_signature,
      :show_in_dashboard,
      :phone_number,
      :start_date,
      :tags
    ])
    |> validate_required([
      :user_id,
      :company_id,
      :terms_accepted,
      :status,
      :name,
      :esign_consented,
      :esign_consent_remote_ip
    ])
  end

  @recipient_info ["email", "name", "organization", "phone_number", "start_date"]

  def get_data_to_map(), do: @recipient_info

  def get_recipient_spec_label(key) do
    case key do
      "email" -> "email_address"
      "name" -> "contact_full_name"
      "organization" -> "organization"
      "phone_number" -> "phone_number"
      "start_date" -> "start_date"
    end
  end

  def all_active_for(company) do
    BoilerPlate.Repo.all(
      from u in BoilerPlate.User,
        join: r in BoilerPlate.Recipient,
        on: r.user_id == u.id,
        select: r,
        where: r.company_id == ^company.id and r.status == 0
    )
  end

  def assignments_of(recipient) do
    BoilerPlate.Repo.all(
      from pa in PackageAssignment,
        where:
          pa.status == 0 and
            pa.recipient_id == ^recipient.id,
        select: pa
    )
  end

  def get_company_recipients_count_by_period(company_id, start_time_period, end_time_period) do
    query =
      from recp in BoilerPlate.Recipient,
        where:
          recp.company_id == ^company_id and recp.status == 0 and
            recp.inserted_at >= ^start_time_period and recp.inserted_at <= ^end_time_period,
        select: recp

    BoilerPlate.Repo.aggregate(query, :count, :id)
  end

  def get_company_deleted_recipients_count_by_period(
        company_id,
        start_time_period,
        end_time_period
      ) do
    query =
      from recp in BoilerPlate.Recipient,
        where:
          recp.company_id == ^company_id and recp.status != 0 and
            recp.updated_at >= ^start_time_period and recp.updated_at <= ^end_time_period,
        select: recp

    BoilerPlate.Repo.aggregate(query, :count, :id)
  end

  @doc """
    Checks if recipient already exists within the company.
    Recipient is shared within the company, and it is not associated with an individual requestor.
    Same recipient email can be assciated within multiple companies.
    The recipient exists if it is present in same company as of requestor, and status is 0.
  Returns `Boolean`
  """
  def exists?(email, company) do
    query =
      from u in BoilerPlate.User,
        join: r in BoilerPlate.Recipient,
        on: r.user_id == u.id,
        where: r.company_id == ^company.id and u.email == ^email,
        select: r

    BoilerPlate.Repo.aggregate(query, :count, :id) > 0
  end
end
