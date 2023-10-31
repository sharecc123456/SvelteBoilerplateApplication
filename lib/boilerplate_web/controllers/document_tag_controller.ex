alias BoilerPlate.Repo
alias BoilerPlate.DocumentTag
alias BoilerPlate.RecipientTag
alias BoilerPlate.Company
import Ecto.Query

defmodule BoilerPlateWeb.DocumentTagController do
  use BoilerPlateWeb, :controller

  def get_tags(conn, %{"id" => company_id, "type" => type}) do
    requestor = get_current_requestor(conn)

    if requestor.company_id != String.to_integer(company_id) do
      conn |> put_status(403) |> text("Forbidden")
    else
      tags =
        case type do
          "document" ->
            Repo.all(
              from dt in DocumentTag,
                where: dt.company_id == ^company_id or is_nil(dt.company_id),
                select: dt
            )
            |> Enum.sort_by(& &1.name, :asc)

          "recipient" ->
            Repo.all(
              from dt in RecipientTag,
                where: dt.company_id == ^company_id or is_nil(dt.company_id),
                select: dt
            )
            |> Enum.sort_by(& &1.name, :asc)

          _ ->
            raise ArgumentError, message: "Invalid tag type"
        end

      case type do
        "document" -> render(conn, "document_tags.json", document_tags: tags)
        "recipient" -> render(conn, "recipient_tags.json", recipient_tags: tags)
      end
    end
  end

  def add_tag(conn, params = %{"id" => company_id, "name" => tag_name, "type" => type}) do
    company = Repo.get(Company, company_id)
    requestor = get_current_requestor(conn)

    flags = params["flags"] || 0

    if requestor != nil and company != nil and company.id == requestor.company_id do
      tag_cs =
        case type do
          "document" ->
            %DocumentTag{
              name: tag_name,
              status: 0,
              company_id: company.id,
              sensitive_level: flags
            }

          "recipient" ->
            %RecipientTag{
              name: tag_name,
              status: 0,
              company_id: company.id,
              sensitive_level: flags
            }
        end

      n = Repo.insert!(tag_cs)
      json(conn, %{id: n.id})
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def get_tag_by_id(conn, %{"id" => id, "type" => type}) do
    requestor = get_current_requestor(conn)

    tag =
      case type do
        "document" -> Repo.get(DocumentTag, id)
        "recipient" -> Repo.get(RecipientTag, id)
      end

    if tag != nil and (tag.company_id == nil or tag.company_id == requestor.company_id) do
      case type do
        "document" -> render(conn, "document_tag.json", document_tag: tag)
        "recipient" -> render(conn, "recipient_tag.json", recipient_tag: tag)
      end
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end
end
