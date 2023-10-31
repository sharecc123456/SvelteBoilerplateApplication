import Bitwise

defmodule BoilerPlate.Company do
  use Ecto.Schema
  import Ecto.Changeset
  use Arc.Definition

  schema "companies" do
    field :name, :string
    field :stripe_customer_id, :string
    field :plan, :string
    field :coupon, :integer
    field :trial_end, :date
    field :trial_max_packages, :integer
    field :next_payment_due, :date

    # Whitelabeling information
    field :whitelabel_image_name, :string, default: ""
    field :whitelabel_enabled, :boolean, default: false

    # MFA
    field :mfa_mandate, :boolean, default: true

    field :status, :integer
    # bit 2 (4) -> impersonate optin
    field :flags, :integer
    field :file_retention_period, :integer, default: -1

    field :temporary_storage_provider, :id
    field :permanent_storage_provider, :id

    timestamps()
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [
      :name,
      :stripe_customer_id,
      :plan,
      :coupon,
      :trial_end,
      :trial_max_packages,
      :next_payment_due,
      :mfa_mandate,
      :whitelabel_image_name,
      :whitelabel_enabled,
      :status,
      :flags,
      :file_retention_period,
      # :company_id,
      # :admin_of,
      :temporary_storage_provider,
      :permanent_storage_provider
    ])
    |> validate_required([:name])
  end

  def impersonate_ok?(company) do
    (company.flags &&& 4) == 4
  end

  def status_to_atom(status) do
    case status do
      0 -> :new_company
      1 -> :free_trial
      2 -> :paid_for
      3 -> :expired
      4 -> :free_trial_expired
      _ -> raise "What the heck"
    end
  end

  def atom_to_status(atom) do
    case atom do
      :new_company -> 0
      :free_trial -> 1
      :paid_for -> 2
      :expired -> 3
      :free_trial_expired -> 4
      _ -> raise "What the heck 2"
    end
  end

  # Arc
  @versions [:original]
  # @acl :public_read

  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end
end

defimpl FunWithFlags.Group, for: BoilerPlate.Company do
  def in?(company, plan) do
    plan == "plan_#{company.plan}"
  end
end

defimpl FunWithFlags.Actor, for: BoilerPlate.Company do
  def id(company) do
    "company:#{company.id}"
  end
end
