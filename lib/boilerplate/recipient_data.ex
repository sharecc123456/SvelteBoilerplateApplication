defmodule BoilerPlate.RecipientData do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %{
          flags: integer,
          label: String.t(),
          status: integer,
          value: map,
          recipient_id: integer
        }

  @type api :: %{
          id: integer,
          label: String.t(),
          type: String.t(),
          source: %{
            type: String.t(),
            origin: String.t(),
            origin_id: integer
          },
          value: any
        }

  schema "recipients_data" do
    field :flags, :integer
    field :label, :string

    # status = 0 => valid
    # status = 1 => superseded
    field :status, :integer

    field :value, :map
    field :recipient_id, :id

    timestamps()
  end

  @doc false
  def changeset(recipient_data, attrs) do
    recipient_data
    |> cast(attrs, [:status, :flags, :label, :value])
    |> validate_required([:status, :flags, :label, :value])
  end
end
