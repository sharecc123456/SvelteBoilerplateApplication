alias BoilerPlate.IACField
alias BoilerPlate.Repo

defmodule BoilerPlate.IACAssignedForm do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iac_assigned_forms" do
    field :company_id, :integer
    field :contents_id, :integer
    field :master_form_id, :integer
    field :recipient_id, :integer
    field :fields, {:array, :integer}

    # status ==1  => stale
    field :status, :integer

    # bit 0 (1) -> rfill_done
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(iacmf, attrs) do
    iacmf
    |> cast(attrs, [
      :company_id,
      :contents_id,
      :master_form_id,
      :recipient_id,
      :fields,
      :status,
      :flags
    ])
    |> validate_required([
      :company_id,
      :contents_id,
      :master_form_id,
      :recipient_id,
      :fields,
      :status,
      :flags
    ])
  end

  def fields_of(iaf) do
    iaf.fields
    |> Enum.map(&Repo.get(IACField, &1))
  end
end
