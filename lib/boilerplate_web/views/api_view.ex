alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.DocumentRequest
alias BoilerPlate.StorageProvider
alias BoilerPlate.RecipientTag
import Ecto.Query
import Bitwise

# Temporary file - we should remove and move renders.

defmodule BoilerPlateWeb.ApiView do
  use BoilerPlateWeb, :view

  ###
  ### Stupid helpers we should move ASAP
  ###

  # TODO move to PackageView
  defp has_allowed_recipient_specific_file_uploads?(pkg) do
    query =
      from r in DocumentRequest,
        where: r.packageid == ^pkg.id and r.flags == 4 and r.status == 0,
        select: r

    ids_count = Repo.aggregate(query, :count, :id)

    if ids_count == 1 do
      true
    else
      false
    end
  end

  # TODO move to PackageView
  defp requests_in(pkg) do
    Repo.all(
      from r in DocumentRequest, where: r.packageid == ^pkg.id and r.status == 0, select: r
    )
    |> Enum.sort_by(& &1.dashboard_order)
  end

  ###
  ### User Me
  ###

  def render("user_me.json", %{requestor: requestor, user: us_user, user_sso: sso}) do
    %{
      name: requestor.name,
      id: requestor.id,
      user_id: us_user.id,
      email: us_user.email,
      phone: us_user.phone_number,
      two_factor_state: us_user.two_factor_state,
      single_sign_on:
        render_many(sso, BoilerPlateWeb.UserSSOView, "user_sso.json", as: :user_sso),
      type: :requestor,
      organization: requestor.organization,
      company_id: requestor.company_id,
      is_notify_admin: requestor.notify_admins,
      is_weekly_digest: requestor.weekly_digest
    }
  end

  def render("user_me.json", %{recipient: recipient, user: us_user, user_sso: sso}) do
    %{
      name: recipient.name,
      email: us_user.email,
      id: recipient.id,
      type: :recipient,
      single_sign_on:
        render_many(sso, BoilerPlateWeb.UserSSOView, "user_sso.json", as: :user_sso),
      organization: recipient.organization
    }
  end

  ###
  ### Requestor
  ###

  def render("requestor.json", %{requestor: r}) do
    u = Repo.get(User, r.user_id)

    %{
      name: r.name,
      requestor_id: r.id,
      user_id: u.id,
      inserted_at: r.inserted_at,
      last_login: u.updated_at,
      email: u.email
    }
  end

  ###
  ### Company
  ###

  def render("company.json", %{company: company}) do
    %{
      id: company.id,
      name: company.name
    }
  end

  def render("user_companies.json", %{
        uid: uid,
        current_recipient_company_name: crcn,
        current_requestor_company_name: creqn,
        current_requestor_company_id: creqi,
        recipient_companies: rcp,
        requestor_companies: rqp
      }) do
    %{
      user_id: uid,
      current_recipient_company_name: crcn,
      current_requestor_company_name: creqn,
      current_requestor_company_id: creqi,
      recipient_companies: render_many(rcp, BoilerPlateWeb.ApiView, "company.json", as: :company),
      requestor_companies: render_many(rqp, BoilerPlateWeb.ApiView, "company.json", as: :company)
    }
  end

  def render("company_info.json", %{company: company, requestors: requestors, integrations: cis}) do
    %{
      info: render_one(company, BoilerPlateWeb.ApiView, "company.json", as: :company),
      mfa_mandate: company.mfa_mandate,
      integrations:
        render_many(cis, BoilerPlateWeb.CompanyIntegrationView, "company_integration.json",
          as: :company_integration
        ),
      storage_providers: %{
        temporary:
          render_one(
            StorageProvider.temporary_of(company),
            BoilerPlateWeb.CompanyIntegrationView,
            "storage_provider.json",
            as: :storage_provider
          ),
        permanent:
          render_one(
            StorageProvider.permanent_of(company),
            BoilerPlateWeb.CompanyIntegrationView,
            "storage_provider.json",
            as: :storage_provider
          )
      },
      requestors:
        render_many(requestors, BoilerPlateWeb.ApiView, "requestor.json", as: :requestor)
    }
  end

  ###
  ### Requests
  ###

  def render("document_request.json", %{document_request: req}) do
    %{
      id: req.id,
      name: req.title,
      description: req.description,
      inserted_at: req.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      type:
        if 2 in req.attributes do
          "data"
        else
          if 1 in req.attributes do
            "task"
          else
            "file"
          end
        end,
      new: false,
      flags: req.flags,
      link: req.link,
      dashboard_order: req.dashboard_order,
      allow_expiration_tracking: req.enable_expiration_tracking,
      is_confirmation_required: req.is_confirmation_required
    }
  end

  ###
  ### DocumentTag
  ###

  def render("document_tag.json", %{document_tag: tag}) do
    %{
      id: tag.id,
      name: tag.name,
      flags: tag.sensitive_level
    }
  end

  ###
  ### Templates
  ###

  ###
  ### Checklist
  ###

  def render("package.json", %{package: pkg}) do
    rds =
      Repo.all(
        from r in BoilerPlate.RawDocument,
          where: fragment("? = ANY(?)", r.id, ^pkg.templates),
          select: r
      )

    %{
      id: pkg.id,
      name: pkg.title,
      description: pkg.description,
      is_draft: pkg.status == 4,
      version_date: "N/A",
      last_used: "N/A",
      inserted_at: pkg.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      inserted_time: pkg.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      updated_at: pkg.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      updated_time: pkg.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      has_rspec: rds |> Enum.any?(&((&1.flags &&& 2) == 2)),
      file_requests:
        render_many(requests_in(pkg), BoilerPlateWeb.ApiView, "document_request.json",
          as: :document_request
        ),
      documents:
        render_many(
          rds,
          BoilerPlateWeb.DocumentView,
          "raw_document.json",
          as: :raw_document
        ),
      allow_duplicate_submission: pkg.allow_duplicate_submission,
      allow_multiple_requests: pkg.allow_multiple_requests,
      allowed_additional_files_uploads: has_allowed_recipient_specific_file_uploads?(pkg),
      enforce_due_date: pkg.enforce_due_date,
      due_date_type: pkg.due_date_type,
      deadline_due: pkg.due_days,
      # TODO render_many(forms)
      forms: BoilerPlateWeb.FormController.get_forms_for_package(pkg.id),
      # TODO render_one(ses_struct)
      ses_struct: BoilerPlateWeb.IACController.ses_get_struct(:checklist, pkg.id),
      is_archived: pkg.is_archived,
      tags:
        Repo.all(from r in RecipientTag, where: r.id in ^pkg.tags, select: r)
          |> render_many(BoilerPlateWeb.DocumentTagView, "recipient_tag.json", as: :recipient_tag)
    }
  end

  def render("packages.json", %{packages: pkgs}) do
    render_many(pkgs, BoilerPlateWeb.ApiView, "package.json", as: :package)
  end
end
