defmodule BoilerPlate.FormSubmission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_submissions" do
    # this will contain data for form fields
    field :form_values, :map, default: %{}
    field :contents_id, :integer
    field :form_id, :integer
    field :return_comments, :string, default: ""
    field :status, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(form_submission, attrs) do
    form_submission
    |> cast(attrs, [
      :form_values,
      :contents_id,
      :form_id,
      :return_comments,
      :status
    ])
    |> validate_required([
      :form_values,
      :contents_id,
      :form_id,
      :status
    ])
  end
end
