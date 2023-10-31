alias BoilerPlate.IACField
alias BoilerPlate.IACDocument

defmodule BoilerPlate.IACMasterForm do
  use Ecto.Schema
  alias BoilerPlate.Repo
  import Ecto.Changeset

  schema "iac_master_forms" do
    field :company_id, :integer
    field :creator_id, :integer
    field :fields, {:array, :integer}
    field :base_pdf, :string
    field :name, :string
    field :description, :string
    field :status, :integer
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(iacmf, attrs) do
    iacmf
    |> cast(attrs, [
      :company_id,
      :creator_id,
      :fields,
      :base_pdf,
      :name,
      :description,
      :status,
      :flags
    ])
    |> validate_required([:company_id, :creator_id, :fields, :base_pdf, :name, :status, :flags])
  end

  # Construct the database schema from the AWS Textract output
  def save(prehistoric_fields, iac_doc, user) do
    raise ArgumentError, message: "IACMasterForm.save/3 should not be used, PLSREMOVE"
    # Create the IACMasterForm first
    iacmf = %BoilerPlate.IACMasterForm{
      company_id: IACDocument.company_id_of(iac_doc),
      creator_id: user.id,
      fields: [],
      base_pdf: iac_doc.file_name,
      name: IACDocument.name_of(iac_doc),
      description: IACDocument.description_of(iac_doc),
      status: 0,
      flags: 0
    }

    iacmf = Repo.insert!(iacmf)

    # Now, save the fields into IACFields with the IACMF being the parent
    ids =
      prehistoric_fields
      |> Enum.map(fn {field_name, field_value, field_type,
                      {field_geom_top, field_geom_left, field_geom_width, field_geom_height}} ->
        iacfd = %IACField{
          parent_id: iacmf.id,
          parent_type: IACField.atom_to_parent_type(:master_form),
          name: field_name,
          location_type: IACField.atom_to_location_type(:textract_topleft),
          location_value_1: field_geom_top / 1,
          location_value_2: field_geom_left / 1,
          location_value_3: field_geom_width / 1,
          location_value_4: field_geom_height / 1,
          location_value_5: 0.0,
          location_value_6: 0.0,
          field_type: field_type |> IACField.field_type_to_int(),
          master_field_id: 0,
          set_value: "",
          default_value: field_value,
          status: 0,
          flags: 0
        }

        iacfd = Repo.insert!(iacfd)

        iacfd.id
      end)

    # Update the MasterForm for the field ids
    cs =
      BoilerPlate.IACMasterForm.changeset(iacmf, %{
        fields: ids
      })

    Repo.update!(cs)

    # Update the Raw Document
    cs =
      IACDocument.changeset(iac_doc, %{
        master_form_id: iacmf.id
      })

    Repo.update!(cs)

    iacmf.id
  end

  # Get the associated master form for the raw document
  def fields_of(iac_doc) do
    iacmf = Repo.get(BoilerPlate.IACMasterForm, iac_doc.master_form_id)

    iacmf.fields
    |> Enum.map(&Repo.get(IACField, &1))
    |> Enum.filter(
      &(IACField.int_to_field_type(&1.field_type) in [:text, :signature, :selection, :table] and
          IACField.displayable_field?(&1))
    )
  end

  def raw_fields_of(iac_doc) do
    iacmf = Repo.get(BoilerPlate.IACMasterForm, iac_doc.master_form_id)

    iacmf.fields
    |> Enum.map(&Repo.get(IACField, &1))
  end
end
