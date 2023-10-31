alias BoilerPlate.RawDocument
alias BoilerPlate.DocumentTag
alias BoilerPlate.IACDocument
alias BoilerPlate.Repo
import Ecto.Query

defmodule BoilerPlateWeb.DocumentView do
  use BoilerPlateWeb, :view

  def render("raw_document.json", %{raw_document: doc}) do
    iac_doc = IACDocument.get_for(:raw_document, doc)

    tags =
      if doc.tags == nil do
        []
      else
        %{
          id: doc.tags,
          values:
            Repo.all(from r in DocumentTag, where: r.id in ^doc.tags, select: r)
            |> render_many(BoilerPlateWeb.ApiView, "document_tag.json", as: :document_tag)
        }
      end

    %{
      id: doc.id,
      name: doc.name,
      description: doc.description,
      company_id: doc.company_id,
      file_name: doc.file_name,
      is_iac: iac_doc != nil,
      iac_doc_id:
        if iac_doc == nil do
          0
        else
          iac_doc.id
        end,
      is_rspec: RawDocument.is_rspec?(doc),
      is_info: RawDocument.is_info?(doc),
      allow_edits: doc.editable_during_review,
      inserted_at: doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      inserted_time: doc.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      updated_at: doc.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      updated_time: doc.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      type: doc.type,
      is_archived: doc.is_archived,
      tags: tags
    }
  end

  def render("raw_documents.json", %{raw_documents: rds}) do
    render_many(rds, BoilerPlateWeb.DocumentView, "raw_document.json", as: :raw_document)
  end
end
