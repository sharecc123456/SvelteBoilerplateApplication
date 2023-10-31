alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.Company
alias BoilerPlate.Cabinet
alias BoilerPlate.Recipient
alias BoilerPlate.Document
require Logger

defmodule BoilerPlateWeb.CabinetController do
  use BoilerPlateWeb, :controller

  ###
  ### API
  ###

  def api_cabinet_replace(us_user, upload, rid, did) do
    recipient = Repo.get(Recipient, rid)
    user = Repo.get(User, recipient.user_id)
    cabinet = Repo.get(Cabinet, did)

    company = Repo.get(Company, recipient.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) and
         cabinet.recipient_id == recipient.id do
      template_fn = UUID.uuid4() <> Path.extname(upload.filename)

      {_status, final_path} =
        Document.store(%{
          filename: template_fn,
          path: upload.path
        })

      cs = Cabinet.changeset(cabinet, %{filename: final_path})
      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

      :ok
    else
      Logger.warn(
        "Forbidden: can't replace cabinet user #{user.name} (id: #{user.id}, email: #{user.email}"
      )

      :forbidden
    end
  end

  def api_cabinet_delete(requestor, uid, did) do
    recipient = Repo.get(Recipient, uid)
    cabinet = Repo.get(Cabinet, did)

    company = Repo.get(Company, recipient.company_id)

    if cabinet != nil and requestor != nil and requestor.company_id == company.id and
         cabinet.recipient_id == recipient.id do
      cs = Cabinet.changeset(cabinet, %{status: 1})
      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      :ok
    else
      user = Repo.get(User, recipient.user_id)

      Logger.warn(
        "Forbidden: can't delete cabinet user #{user.name} (id: #{user.id}, email: #{user.email}"
      )

      :forbidden
    end
  end

  def api_cabinet_new(requestor, uid, upl, docname) do
    cond do
      docname == nil || docname == "" ->
        :no_name

      upl == nil ->
        :no_upload

      True ->
        recipient = Repo.get(Recipient, uid)
        user = Repo.get(User, recipient.user_id)
        company = Repo.get(Company, recipient.company_id)

        if requestor != nil and recipient.company_id == requestor.company_id do
          template_fn = UUID.uuid4() <> Path.extname(upl.filename)

          {_status, final_path} =
            Document.store(%{
              filename: template_fn,
              path: upl.path
            })

          cabinet = %Cabinet{
            name: docname,
            recipient_id: recipient.id,
            requestor_id: requestor.id,
            company_id: company.id,
            filename: final_path,
            status: 0,
            flags: 0
          }

          Repo.insert!(cabinet)
          BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
          :ok
        else
          Logger.warn(
            "Forbidden: can't upload cabinet user #{user.name} (id: #{user.id}, email: #{user.email}"
          )

          :forbidden
        end
    end
  end

  ###
  ### Plug Calls
  ###

  def show(conn, %{"id" => id}) do
    company = get_current_requestor(conn, as: :company)
    recp = Repo.get(Recipient, id)

    if company == nil or recp == nil or company.id != recp.company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      conn
      |> render("cabinets.json", %{
        cabinets:
          Repo.all(
            from c in Cabinet,
              where: c.company_id == ^company.id and c.recipient_id == ^recp.id and c.status == 0,
              select: c
          )
      })
    end
  end

  def create(conn, %{"id" => id, "upload" => upl, "name" => name}) do
    requestor = get_current_requestor(conn)

    case api_cabinet_new(requestor, id, upl, name) do
      :ok -> text(conn, "OK")
      :forbidden -> conn |> put_status(403) |> text("Forbidden")
    end
  end

  def delete(conn, %{"cid" => id, "id" => recipient_id}) do
    requestor = get_current_requestor(conn)

    case api_cabinet_delete(requestor, recipient_id, id) do
      :ok -> text(conn, "OK")
      :forbidden -> conn |> put_status(403) |> text("Forbidden")
    end
  end

  def update(conn, %{
        "cid" => id,
        "upload" => upl,
        "rid" => recipient_id
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    case api_cabinet_replace(us_user, upl, recipient_id, id) do
      :ok -> text(conn, "OK")
      res -> conn |> put_status(400) |> text(res)
    end
  end
end
