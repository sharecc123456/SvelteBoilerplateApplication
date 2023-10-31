import Bitwise

defmodule BoilerPlate.IACSignatureHash do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iac_signature_hashes" do
    field :signature_hash, :string
    field :signature_id, :integer
    field :audit_ip, :string
    field :audit_user, :integer
    field :audit_sign_start, :utc_datetime
    field :audit_sign_end, :utc_datetime
    field :status, :integer
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(iacfd, attrs) do
    iacfd
    |> cast(attrs, [
      :signature_hash,
      :signature_id,
      :audit_ip,
      :audit_user,
      :audit_sign_start,
      :audit_sign_end,
      :status,
      :flags
    ])
    |> validate_required([
      :signature_hash,
      :signature_id,
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
        :delete -> a ||| 1
        :superseded -> a ||| 2
        _ -> a
      end
    end)
  end
end
