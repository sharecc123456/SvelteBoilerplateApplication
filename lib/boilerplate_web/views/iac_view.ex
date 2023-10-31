alias BoilerPlate.Repo
alias BoilerPlate.IACField
alias BoilerPlate.IACMasterForm
alias BoilerPlate.RawDocument
alias BoilerPlate.IACSignature

defmodule BoilerPlateWeb.IACView do
  use BoilerPlateWeb, :view

  def sighash_to_document(sighash) do
    iacsig = Repo.get(IACSignature, sighash.signature_id)
    field = Repo.get(IACField, iacsig.signature_field)

    if IACField.parent_type_to_atom(field.parent_type) == :master_form do
      imf = Repo.get(IACMasterForm, field.parent_id)
      doc = Repo.get_by(RawDocument, iac_master_id: imf.id)
      doc
    else
      masterfield = Repo.get(IACField, field.master_field_id)
      imf = Repo.get(IACMasterForm, masterfield.parent_id)
      doc = Repo.get_by(RawDocument, iac_master_id: imf.id)

      if is_nil(doc) do
        imf
      else
        doc
      end
    end
  end
end
