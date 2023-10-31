import Bitwise

defmodule BoilerPlate.IACSignature do
  use Ecto.Schema
  alias BoilerPlate.Repo
  import Ecto.Changeset
  import Ecto.Query

  schema "iac_signatures" do
    field :signature_file, :string
    field :signature_field, :integer
    field :audit_ip, :string
    field :audit_user, :integer
    field :audit_sign_start, :utc_datetime
    field :audit_sign_end, :utc_datetime
    field :signee_version, :integer, default: 0
    field :signee_type, :integer, default: 0
    field :signee_id, :integer, default: 0
    field :status, :integer
    field :flags, :integer

    timestamps()
  end

  def supports_signee_type?(iacsig), do: iacsig != nil and iacsig.signee_version > 1

  def signee_type_to_atom(0), do: :unknown
  def signee_type_to_atom(1), do: :recipient
  def signee_type_to_atom(2), do: :requestor
  def signee_type_to_atom(_), do: :unknown

  def atom_to_signee_type(:recipient), do: 1
  def atom_to_signee_type(:requestor), do: 2
  def atom_to_signee_type(_), do: 0

  @doc false
  def changeset(iacfd, attrs) do
    iacfd
    |> cast(attrs, [
      :signature_file,
      :signature_field,
      :audit_ip,
      :audit_user,
      :audit_sign_start,
      :audit_sign_end,
      :signee_version,
      :signee_type,
      :signee_id,
      :status,
      :flags
    ])
    |> validate_required([
      :signature_file,
      :signature_field,
      :audit_ip,
      :audit_user,
      :audit_sign_start,
      :audit_sign_end,
      :status,
      :flags
    ])
  end

  def flags(stuff) do
    stuff
    |> Enum.reduce(0, fn e, a ->
      case e do
        # deleted
        :delete -> a ||| 1
        # signature_file is a dataurl
        :dataurl -> a ||| 2
        # prefilled signature by the requestor
        :requestor -> a ||| 4
        _ -> a
      end
    end)
  end

  def count_total_signatures_for_company_by_period(user_ids, start_time_period, end_time_period) do
    query =
      from iacsign in BoilerPlate.IACSignature,
        # count repeat submission packages
        where:
          iacsign.audit_user in ^user_ids and iacsign.audit_sign_start >= ^start_time_period and
            iacsign.audit_sign_start <= ^end_time_period,
        select: iacsign

    Repo.aggregate(query, :count, :id)
  end
end
