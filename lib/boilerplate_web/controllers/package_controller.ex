alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.Recipient
alias BoilerPlate.Package
alias BoilerPlate.PackageContents
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RawDocumentCustomized
alias BoilerPlate.RequestCompletion
alias BoilerPlate.RawDocument
alias BoilerPlate.PackageAssignment
alias BoilerPlateWeb.FormController
alias BoilerPlate.FileCleanerUtils
import Ecto.Query
import BoilerPlate.AuditLog
require Logger
import Bitwise

defmodule BoilerPlateWeb.PackageController do
  use BoilerPlateWeb, :controller

  def api_delete_package(us_user, pid) do
    pkg = Repo.get(Package, pid)
    pkg_company = Repo.get(Company, pkg.company_id)

    if BoilerPlate.Policy.can_delete?(:package, pkg) do
      if BoilerPlate.AccessPolicy.has_admin_access_to?(pkg_company, us_user) do
        audit(:package_delete, %{
          user: us_user,
          package: pkg,
          package_id: pkg.id,
          company_id: pkg_company.id
        })

        Repo.update!(Package.changeset(pkg, %{status: 1}))

        :ok
      else
        audit(:package_delete_failure, %{user: us_user, package_id: pkg.id, reason: 2})

        :forbidden
      end
    else
      audit(:package_delete_failure, %{user: us_user, package_id: pkg.id, reason: 1})

      :already_assigned
    end
  end

  def api_upload_customize_package(requestor, us_user, cid, rid, rsdid, upl, version \\ 1) do
    template_fn = UUID.uuid4() <> Path.extname(upl.filename)
    rd = Repo.get(RawDocument, rsdid)
    recipient = Repo.get(Recipient, rid)
    contents = Repo.get(PackageContents, cid)
    package = Repo.get(Package, contents.package_id)
    package_company = Repo.get(Company, package.company_id)
    document_company = Repo.get(Company, rd.company_id)
    user_company = Repo.get(Company, recipient.company_id)

    if requestor != nil and
         user_company.id == requestor.company_id and
         package_company.id == requestor.company_id and package.status == 0 do
      {status, final_path} =
        RawDocumentCustomized.store(%{
          filename: template_fn,
          path: upl.path
        })

      if status == :ok do
        rdc = %RawDocumentCustomized{
          raw_document_id: rd.id,
          contents_id: contents.id,
          recipient_id: recipient.id,
          file_name: final_path,
          status: 0,
          flags: 0,
          version: version
        }

        nrdc = Repo.insert!(rdc)

        audit(:contents_rsd_upload, %{
          user: us_user,
          company_id: document_company.id,
          recipient_id: recipient.id,
          contents_id: contents.id,
          document_id: rd.id,
          customized_id: nrdc.id,
          final_path: final_path
        })

        :ok
      else
        audit(:contents_rsd_upload_failure, %{
          user: us_user,
          company_id: document_company.id,
          recipient_id: recipient.id,
          contents_id: contents.id,
          document_id: rd.id,
          reason: 1
        })

        :error
      end
    else
      audit(:contents_rsd_upload_failure, %{
        user: us_user,
        company_id: document_company.id,
        recipient_id: recipient.id,
        contents_id: contents.id,
        document_id: rd.id,
        reason: 2
      })

      :forbidden
    end
  end

  def api_add_request(us_user, title, pid) do
    package = Repo.get(Package, pid)
    package_company = Repo.get(Company, package.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(package_company, us_user) do
      if title["name"] == nil or title["name"] == "" do
        audit(:package_request_add_failure, %{
          user: us_user,
          company_id: package_company.id,
          package_id: package.id,
          request_name: title["name"],
          reason: 1
        })

        :missing_title
      else
        # Check if a request with this name exists already
        x_q =
          from dr in DocumentRequest,
            where: dr.packageid == ^package.id and dr.title == ^title["name"] and dr.status == 0,
            select: dr

        if Repo.aggregate(x_q, :count, :id) > 0 do
          audit(:package_request_add_failure, %{
            user: us_user,
            company_id: package_company.id,
            package_id: package.id,
            request_name: title["name"],
            reason: 3
          })

          :already_exists
        else
          type = title["type"]

          attrs =
            if type == "file" or type == "allow_extra_files" do
              []
            else
              if type == "task" do
                [1]
              else
                [2]
              end
            end

          flags =
            if type == "allow_extra_files" do
              4
            else
              0
            end

          link =
            if type == "task" do
              title["link"]
            else
              %{}
            end

          allow_expiration_tracking = title["allow_expiration_tracking"] || false

          req = %DocumentRequest{
            packageid: package.id,
            title: title["name"],
            description: title["description"],
            status: 0,
            attributes: attrs,
            flags: flags,
            link: link,
            dashboard_order: title["order"],
            enable_expiration_tracking: allow_expiration_tracking,
            is_confirmation_required: title["is_confirmation_required"] || false
          }

          audit(:package_request_add, %{
            user: us_user,
            company_id: package_company.id,
            request_name: title["name"],
            package_id: package.id
          })

          Repo.insert!(req)

          :ok
        end
      end
    else
      audit(:package_request_add_failure, %{
        user: us_user,
        company_id: package_company.id,
        package_id: package.id,
        request_name: title["name"],
        reason: 2
      })

      :forbidden
    end
  end

  def api_delete_request(us_user, rid, pid) do
    req = Repo.get(DocumentRequest, rid)
    package = Repo.get(Package, pid)
    package_company = Repo.get(Company, package.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(package_company, us_user) do
      if req.packageid == package.id do
        audit(:package_request_delete, %{
          user: us_user,
          company_id: package_company.id,
          request_name: req.title,
          package_id: package.id
        })

        Repo.update!(DocumentRequest.changeset(req, %{status: 1}))

        :ok
      else
        audit(:package_request_delete_failure, %{
          user: us_user,
          company_id: package_company.id,
          request_name: req.title,
          package_id: package.id,
          reason: 2
        })

        :forbidden
      end
    else
      audit(:package_request_delete_failure, %{
        user: us_user,
        company_id: package_company.id,
        request_name: req.title,
        package_id: package.id,
        reason: 2
      })

      :forbidden
    end
  end

  def api_duplicate_package(requestor, us_user, pid) do
    package = Repo.get(Package, pid)
    package_company = Repo.get(Company, package.company_id)

    if requestor != nil and
         BoilerPlate.AccessPolicy.has_admin_access_to?(package_company, us_user) do
      n =
        Repo.insert!(%Package{
          templates: package.templates,
          title: "#{package.title} - Duplicate",
          status: 0,
          description: "#{package.description} - Duplicate",
          company_id: package.company_id,
          enforce_due_date: package.enforce_due_date,
          due_date_type: package.due_date_type,
          due_days: package.due_days,
          tags: package.tags
        })

      # Duplicate the forms
      FormController.duplicate_forms(package.id, n.id)

      # Duplicate the requests
      for request <-
            Repo.all(
              from r in DocumentRequest,
                where: r.packageid == ^package.id and r.status == 0,
                select: r
            ) do
        Repo.insert!(%DocumentRequest{
          packageid: n.id,
          title: request.title,
          attributes: request.attributes,
          description: request.description,
          status: 0,
          dashboard_order: request.dashboard_order,
          has_file_uploads: false,
          link: request.link,
          enable_expiration_tracking: request.enable_expiration_tracking,
          file_retention_period: request.file_retention_period,
          is_confirmation_required: request.is_confirmation_required
        })
      end

      audit(:package_duplicate, %{
        user: us_user,
        company_id: package_company.id,
        package_id: package.id,
        package_name: package.title,
        new_package_id: n.id
      })

      {:ok, n.id}
    else
      audit(:package_duplicate_failure, %{
        user: us_user,
        company_id: package_company.id,
        package_id: package.id,
        package_name: package.title,
        reason: 2
      })

      {:forbidden, 0}
    end
  end

  defp adhoc_ok_for?(pkg) do
    tlist = pkg.templates

    rsd_count =
      Repo.all(from r in BoilerPlate.RawDocument, where: r.id in ^tlist, select: r)
      |> Enum.filter(&((&1.flags &&& 2) != 0))
      |> length()

    rsd_count == 0
  end

  def api_make_adhoc_link_package(requestor, us_user, pid) do
    package = Repo.get(Package, pid)
    package_company = Repo.get(Company, package.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(package_company, us_user) do
      if adhoc_ok_for?(package) do
        {adhoc_link, adh} = Package.make_adhoc_link(package, requestor)

        audit(:package_adhoc_create, %{
          user: us_user,
          package_id: package.id,
          company_id: package_company.id,
          adhoc_string: adh.adhoc_string
        })

        {:ok, adhoc_link}
      else
        :intake_with_rsds
      end
    else
      audit(:package_adhoc_failure, %{
        user: us_user,
        package_id: package.id,
        company_id: package_company.id
      })

      :forbidden
    end
  end

  def api_delete_assignment(requestor, us_user, uid, aid) do
    recipient = Repo.get(Recipient, uid)
    recipient_company = Repo.get(Company, recipient.company_id)
    assign = Repo.get(PackageAssignment, aid)
    pkg_company = Repo.get(Company, Repo.get(Package, assign.package_id).company_id)

    if requestor.company_id == recipient_company.id and
         requestor.company_id == pkg_company.id do
      if assign != nil do
        Logger.info("[uid #{us_user.id}] Deleting assignment #{aid}")

        FileCleanerUtils.delete_assignment_files(aid)

        # for d <- Repo.all(from d in Document, where: d.assignment_id == ^assign.id, select: d) do
        #   changeset = %{
        #     status: 4,
        #     filename: d.filename <> ".del"
        #   }
        #   cs = Document.changeset(d, changeset)
        #   Repo.update!(cs)
        # end

        # for d <-
        #       Repo.all(
        #         from d in RequestCompletion, where: d.assignment_id == ^assign.id, select: d
        #       ) do
        #   changeset = %{
        #     status: 4,
        #     file_name: d.file_name <> ".del"
        #   }
        #   cs = RequestCompletion.changeset(d, changeset)
        #   Repo.update!(cs)
        # end

        # Repo.update!(PackageAssignment.changeset(assign, %{status: 2}))

        audit(:assignment_delete, %{
          user: us_user,
          company_id: requestor.company_id,
          recipient_id: recipient.id,
          package_id: assign.package_id,
          assignment_id: assign.id
        })
      end

      :ok
    else
      audit(:assignment_delete_failed, %{
        user: us_user,
        company_id: requestor.company_id,
        recipient_id: recipient.id,
        package_id: assign.package_id,
        assignment_id: assign.id,
        reason: 2
      })

      :forbidden
    end
  end

  def get_company_file_uploads_count_by_period(
        company_id,
        start_time_period,
        end_time_period,
        type
      ) do
    requests =
      PackageContents
      # valid, archived and deleted
      |> join(:inner, [pkgcontent], pa in PackageAssignment,
        on: pa.contents_id == pkgcontent.id and pa.company_id == ^company_id
      )
      |> Repo.all()
      |> Enum.map(& &1.requests)
      |> List.foldl([], &(&1 ++ &2))

    case type do
      "data" ->
        DocumentRequest
        # attribute file as empty array https://hexdocs.pm/ecto/Ecto.Query.API.html#fragment/1
        |> where([docreq], docreq.id in ^requests and fragment("? = '{2}'", docreq.attributes))
        |> join(:inner, [docreq], rc in RequestCompletion,
          on:
            docreq.id == rc.requestid and rc.status > 0 and rc.inserted_at >= ^start_time_period and
              rc.inserted_at <= ^end_time_period
        )
        |> Repo.aggregate(:count, :id)

      "files" ->
        DocumentRequest
        # attribute file as empty array https://hexdocs.pm/ecto/Ecto.Query.API.html#fragment/1
        |> where([docreq], docreq.id in ^requests and fragment("? = '{}'", docreq.attributes))
        |> join(:inner, [docreq], rc in RequestCompletion,
          on:
            docreq.id == rc.requestid and rc.status > 0 and rc.inserted_at >= ^start_time_period and
              rc.inserted_at <= ^end_time_period
        )
        |> Repo.aggregate(:count, :id)

      "task" ->
        DocumentRequest
        # attribute file as empty array https://hexdocs.pm/ecto/Ecto.Query.API.html#fragment/1
        |> where([docreq], docreq.id in ^requests and fragment("? = '{1}'", docreq.attributes))
        |> join(:inner, [docreq], rc in RequestCompletion,
          on:
            docreq.id == rc.requestid and rc.status > 0 and rc.inserted_at >= ^start_time_period and
              rc.inserted_at <= ^end_time_period
        )
        |> Repo.aggregate(:count, :id)

      _ ->
        0
    end
  end
end
