defmodule BoilerPlate.Form do
  use Ecto.Schema
  import Ecto.Changeset

  schema "forms" do
    field :title, :string
    field :description, :string, default: "-"
    field :status, :integer, default: 0
    field :package_id, :integer
    field :master_form_id, :integer, default: nil
    field :has_repeat_entries, :boolean, default: false
    field :has_repeat_vertical, :boolean, default: false
    field :repeat_label, :string, default: ""
    field :file_retention_period, :integer, default: nil
    field :repeat_entry_default_value, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [
      :title,
      :description,
      :status,
      :package_id,
      :master_form_id,
      :has_repeat_entries,
      :has_repeat_vertical,
      :repeat_label,
      :repeat_entry_default_value
    ])
    |> validate_required([
      :title,
      :package_id
    ])
  end
end
