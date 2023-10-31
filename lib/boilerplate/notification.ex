defmodule BoilerPlate.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification" do
    field :type, :string, default: ""
    field :title, :string

    field :message, :string
    field :assignment_id, :id
    field :company_id, :id
    # 0 -> unread
    # 1 -> read
    field :flags, :integer, default: 0
    # 1 -> archived
    field :status, :integer, default: 0
    field :user_id, :integer
    field :document_id, :integer
    field :document_type, :string

    timestamps()
  end

  @doc false
  def changeset(raw_document, attrs) do
    raw_document
    |> cast(attrs, [
      :message,
      :title,
      :type,
      :company_id,
      :type,
      :flags,
      :assignment_id,
      :document_id,
      :document_type,
      :user_id,
      :status
    ])
    |> validate_required([:message, :company_id, :type, :flags, :user_id])
  end

  def flags_type_to_atom(flag) do
    case flag do
      0 -> :unread
      1 -> :read
      _ -> :unknown
    end
  end

  def status_type_to_atom(status) do
    case status do
      0 -> :active
      1 -> :archived
      _ -> :unknown
    end
  end

  def flags_type_to_read_bool(flag) do
    case flag do
      0 -> false
      1 -> true
    end
  end

  def atom_to_flag_type(atom) do
    case atom do
      :unread -> 0
      :read -> 1
    end
  end
end
