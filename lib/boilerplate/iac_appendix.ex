defmodule BoilerPlate.IACAppendix do
  use Ecto.Schema
  use Arc.Definition
  import Ecto.Changeset

  schema "iac_appendices" do
    # the IAC document of the target document
    field :iac_assigned_form_id, :id

    # The form from which this appendix was generated.
    field :form_id, :id

    # The file name of the appendix, stored in S3.
    field :appendix_name, :string, default: ""

    # The order of the appendix, 0 first, 1 second, etc.
    field :appendix_order, :integer, default: 0

    # Label to which this appendix refers to.
    field :appendix_label, :string, default: ""

    # Reference
    field :appendix_reference, :string, default: ""

    # IAC/SES internal version number (to support transparent IAC/SES upgrades)
    field :version, :integer, default: 0

    # Misc fields for other upgrades later
    field :status, :integer, default: 0
    field :flags, :integer, default: 0
    timestamps()
  end

  @doc false
  def changeset(ise, attrs) do
    ise
    |> cast(attrs, [
      :iac_assigned_form_id,
      :form_id,
      :appendix_name,
      :appendix_order,
      :appendix_label,
      :appendix_reference,
      :version,
      :status,
      :flags
    ])
    |> validate_required([
      :appendix_name,
      :version,
      :status,
      :flags
    ])
  end

  # Arc
  @versions [:original]
  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end
end
