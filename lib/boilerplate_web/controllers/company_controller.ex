alias BoilerPlate.Company
alias BoilerPlate.User
alias BoilerPlate.Requestor
alias BoilerPlate.Repo
alias BoilerPlate.Helpers
alias BoilerPlate.StorageProvider
import Ecto.Query
require Logger

defmodule BoilerPlateWeb.CompanyController do
  use BoilerPlateWeb, :controller

  def get_company_admins(conn, %{"id" => _aid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      company = Repo.get(Company, requestor.company_id)

      if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
        administrators =
          Repo.all(
            from u in User,
              join: req in Requestor,
              on: req.user_id != ^us_user.id and req.user_id == u.id,
              where: u.company_id == ^company.id and req.status == 0,
              select: u
          )
          |> Enum.map(
            &%{
              name: &1.name,
              email: &1.email,
              company: &1.organization
            }
          )

        json(conn, administrators)
      else
        conn |> put_status(403) |> text("Forbidden")
      end
    end
  end

  def upload_logo(conn, params) do
    requestor = get_current_requestor(conn)

    {company_id, _} = Integer.parse(params["company_id"])

    file = params["file"]
    allowed_extensions = [".jpg", ".jpeg", ".png", ".svg"]
    allow_upload = Helpers.file_validator?(file.filename, allowed_extensions)

    if company_id == requestor.company_id && allow_upload do
      uuid_file_name = UUID.uuid4() <> Path.extname(file.filename)

      {_status, final_path} =
        Company.store(%{
          filename: uuid_file_name,
          path: file.path
        })

      conn |> json(%{msg: "OK", logo: final_path})
    else
      if allow_upload == false do
        # file was of allowed format
        conn |> put_status(400) |> text("Invalid Filetype")
      else
        conn |> put_status(403) |> text("Forbidden")
      end
    end
  end

  def add_white_label(conn, params) do
    requestor = get_current_requestor(conn)

    company_id = params["company_id"]

    logo = params["logo"]

    if company_id == requestor.company_id do
      company = Repo.get(Company, company_id)

      cs = %{
        whitelabel_image_name: logo,
        whitelabel_enabled: true
      }

      changeset = Company.changeset(company, cs)

      Repo.update!(changeset)

      conn |> json(%{msg: "OK"})
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def update_storage_provider(conn, %{"type" => "permanent", "path_template" => pt}) do
    company = get_current_requestor(conn, as: :company)

    if company == nil do
      conn |> put_status(403) |> json(%{error: :forbidden})
    else
      case StorageProvider.update_path_template(company, :permanent, pt) do
        {:ok, _} -> text(conn, "OK")
        {:error, _} -> conn |> put_status(500) |> json(%{error: :bad_changeset})
      end
    end
  end
end
