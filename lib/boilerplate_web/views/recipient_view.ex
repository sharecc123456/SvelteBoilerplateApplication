alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.RecipientTag

defmodule BoilerPlateWeb.RecipientView do
  use BoilerPlateWeb, :view
  import Ecto.Query

  ###
  ### Render Calls
  ###

  def render("data_tab_entry_source.json", %{data_tab_entry_source: dtes}) do
    %{type: dtes.type, origin: dtes.origin, origin_id: dtes.origin_id}
  end

  def render("data_tab_entry.json", %{data_tab_entry: dte}) do
    %{
      id: dte.id,
      label: dte.label,
      type: dte.type,
      source:
        render_one(
          dte.source,
          BoilerPlateWeb.RecipientView,
          "data_tab_entry_source.json",
          as: :data_tab_entry_source
        ),
      updated: dte.updated,
      value: dte.value
    }
  end

  def render("data_tab.json", %{data_tab: dt}) do
    render_many(dt, BoilerPlateWeb.RecipientView, "data_tab_entry.json", as: :data_tab_entry)
  end

  def render("recipient.json", %{recipient: recp}) do
    tags =
      if recp.tags == nil do
        []
      else
        %{
          id: recp.tags,
          values:
            Repo.all(from r in RecipientTag, where: r.id in ^recp.tags, select: r)
            |> render_many(BoilerPlateWeb.DocumentTagView, "recipient_tag.json",
              as: :recipient_tag
            )
        }
      end

    %{
      id: recp.id,
      name: recp.name,
      company_id: recp.company_id,
      email: Repo.get(User, recp.user_id).email,
      added: recp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      added_time: recp.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      last_modified: recp.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      modified_time: recp.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      company: recp.organization,
      phone_number: recp.phone_number,
      show_in_dashboard: recp.show_in_dashboard,
      email_editable: BoilerPlateWeb.RecipientController.recipient_email_editable(recp),
      is_deleted: recp.status == 1,
      # XXX(unify this)
      deleted: recp.status == 1,
      start_date:
        if(recp.start_date != nil,
          do: recp.start_date |> Timex.format!("{YYYY}-{0M}-{0D}"),
          else: ""
        ),
      user_id: recp.user_id,
      tags: tags
    }
  end

  def render("recipients.json", %{recipients: recps}) do
    render_many(recps, BoilerPlateWeb.RecipientView, "recipient.json", as: :recipient)
  end

  def render("recipients_paginated.json", %{
        data: recps,
        total_pages: total_pages,
        page: page,
        has_next: has_next,
        count: count
      }) do
    %{
      data: render_many(recps, BoilerPlateWeb.RecipientView, "recipient.json", as: :recipient),
      total_pages: total_pages,
      page: page,
      has_next: has_next,
      count: count
    }
  end
end
