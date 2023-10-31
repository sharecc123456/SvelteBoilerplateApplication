defmodule BoilerPlate.FormField do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_fields" do
    field :title, :string
    field :label, :string, default: ""
    field :description, :string, default: "-"
    field :type, :string
    field :required, :boolean
    field :options, {:array, :string}, default: []
    field :form_id, :integer
    field :is_numeric, :boolean, default: false
    field :is_multiple, :boolean, default: false
    field :order_id, :integer, default: 0
    field :status, :integer, default: 0
    field :default_value, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(form_field, attrs) do
    form_field
    |> cast(attrs, [
      :title,
      :label,
      :description,
      :type,
      :required,
      :options,
      :form_id,
      :is_numeric,
      :is_multiple,
      :status,
      :order_id,
      :default_value
    ])
    |> validate_required([
      :title,
      :type,
      :required,
      :form_id
    ])
  end
end
