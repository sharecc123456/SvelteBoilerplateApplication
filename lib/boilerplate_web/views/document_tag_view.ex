defmodule BoilerPlateWeb.DocumentTagView do
  use BoilerPlateWeb, :view

  def render("document_tag.json", %{document_tag: tag}) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color,
      company: tag.company_id,
      flags: tag.sensitive_level,
      created_at: tag.inserted_at
    }
  end

  def render("document_tags.json", %{document_tags: tags}) do
    render_many(tags, BoilerPlateWeb.DocumentTagView, "document_tag.json", as: :document_tag)
  end

  def render("recipient_tag.json", %{recipient_tag: tag}) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color,
      company: tag.company_id,
      flags: tag.sensitive_level,
      created_at: tag.inserted_at
    }
  end

  def render("recipient_tags.json", %{recipient_tags: tags}) do
    render_many(tags, BoilerPlateWeb.DocumentTagView, "recipient_tag.json", as: :recipient_tag)
  end
end
