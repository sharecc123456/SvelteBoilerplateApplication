defmodule BoilerPlateWeb.Router do
  use BoilerPlateWeb, :router
  use Plug.ErrorHandler
  require Logger

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery, with: :exception
    plug :put_secure_browser_headers
    plug BoilerPlatePlug.Stats
  end

  pipeline :pre_auth do
    plug :fetch_session

    plug Guardian.Plug.Pipeline,
      module: BoilerPlate.Guardian,
      error_handler: BoilerPlate.GuardianErrorHandler

    plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
    plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
    plug Guardian.Plug.LoadResource, allow_blank: true
  end

  pipeline :auth do
    plug :pre_auth
    plug Guardian.Plug.EnsureAuthenticated

    unless Application.compile_env(:boilerplate, :boilerplate_environment) == :test do
      plug BoilerPlate.Guardian.EnsureEmailVerified
      plug BoilerPlate.Guardian.EnsureTermsAccepted
      plug BoilerPlate.Guardian.Ensure2FA
    end
  end

  pipeline :internal_only do
    plug :auth
    plug BoilerPlate.Guardian.EnsureInternalOnly
  end

  pipeline :requestor_only do
    plug BoilerPlate.Guardian.EnsureRequestorAccess
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :put_secure_browser_headers
    plug BoilerPlatePlug.Stats
  end

  scope path: "/internal/ff" do
    pipe_through :internal_only
    forward "/", FunWithFlags.UI.Router, namespace: "internal/ff"
  end

  scope "/", BoilerPlateWeb do
    pipe_through [:browser, :pre_auth]

    get "/", PageController, :index
    get "/internal/testcrash", InternalController, :test_crash
    get "/internal/sessionlog", InternalController, :test_dump_session

    get "/pricing", PageController, :pricing
    get "/internal/version", InternalController, :version
    get "/terms", PageController, :termsofservice
    get "/terms/accept", UserController, :accept_termsofservice

    get "/login", UserController, :login
    post "/login", UserController, :do_login

    get "/logout", UserController, :logout

    get "/password/reset", UserController, :navigate_reset_password
    get "/password/reset/:uid/:hash", UserController, :reset_password
    post "/password/reset", UserController, :do_reset_password

    get "/email/verification/:verification_code", UserController, :verify_email
    get "/email/verification/:uid/resend", UserController, :resend_verify_email

    get "/forgot/password", UserController, :forgot_password
    post "/forgot/password", UserController, :do_forgot_password

    get "/adhoc/:adhoc_str", UserController, :handle_adhoc_link
    post "/adhoc/:adhoc_str/register", UserController, :handle_adhoc_register

    get "/user/:uid/login/:loginhash", UserController, :login_recipient
    get "/v2/user/:uid/login/:loginhash", UserController, :login_recipient_v2
    post "/user/:uid/login/:loginhash", UserController, :do_login_recipient

    # IAC
    get "/verify/signature/:sighash", IACController, :do_verify_signature
    get "/verify/signature", StormwindController, :verify_signature

    get "/_oauth/callback", IntegrationController, :oauth_callback
  end

  scope "/n/", BoilerPlateWeb do
    pipe_through [:browser]

    get "/login", StormwindController, :login

    pipe_through [:auth]

    get "/recipient", StormwindController, :recipient_side
    get "/recipientc", StormwindController, :recipientchoice

    pipe_through [:requestor_only]
    get "/requestorc", IronforgeController, :requestorchoice
    get "/requestor", IronforgeController, :requestor_side

    get "/auth/:integration_type", IntegrationController, :authorize_integration
  end

  scope "/n/api/v1", BoilerPlateWeb do
    pipe_through [:api]

    post "/token", ApiController, :get_token
    post "/login", ApiController, :do_login
    post "/loginsso", ApiController, :do_login_sso

    # TODO lock this down
    get "/user/lookup", ApiController, :user_lookup
    post "/user/adhoc/register", ApiController, :user_adhoc_register
    # TODO lock this down
    post "/user/adhoc/assign", ApiController, :user_adhoc_assign

    post "/user/setpwd", ApiController, :user_set_password
    post "/forgot/password", ApiController, :user_forgot_password

    get "/adhoc", ApiController, :adhoc_details
    post "/internal/telemetry", InternalController, :telemetry_dump

    post "/internal/assignment/deliveryfault", ApiController, :do_delivery_fault
    post "/internal/assignment/cleardeliveryfault", ApiController, :do_clear_delivery_fault

    pipe_through [:pre_auth]
    # MFA
    post "/user/:id/mfa", ApiController, :user_handle_mfa
    # misc
    get "/whitelabel", ApiController, :whitelabel_info
    get "/internal/features", ApiController, :get_features
    post "/internal/crashreport", ApiController, :file_crash_report

    # Text Signature
    put "/user/add_text_signature", UserController, :add_text_signature
    get "/user/get_text_signature", UserController, :get_text_signature
  end

  scope "/n/api/v1", BoilerPlateWeb do
    pipe_through [:api, :auth]

    # Authorize an SSO
    post "/auth/sso", IntegrationController, :add_sso
    post "/deauth/:integration_type", IntegrationController, :deauthorize_integration

    # Shared API
    #    Tested APIs
    get "/user/me", ApiController, :user_me
    get "/user/companies", ApiController, :user_companies
    get "/company/info", ApiController, :requestor_get_company_info
    #    Untested APIs
    post "/user/restrict", ApiController, :user_restrict
    put "/user/:id/profile", ApiController, :user_update_profile
    get "/user/hash", UserController, :api_get_reset_password_hash
    post "/user/password", UserController, :api_change_password
    post "/user/retrieve-link", UserController, :retrieve_link

    put "/company/storageprovider", CompanyController, :update_storage_provider
    post "/company/add-white-label", CompanyController, :add_white_label
    post "/company/upload-white-label", CompanyController, :upload_logo

    get "/company/:id/admin", CompanyController, :get_company_admins

    post "/internal/iac/regenerate", IACController, :iac_internal_regenerate

    get "/iac", ApiController, :iac_get_iac_document
    # HACK
    get "/iac/prefilled", ApiController, :iac_get_prefilled
    post "/iac/field/:field_id/shadowform", FormController, :iac_attach_form
    put "/iac/field/:field_id/shadowform", FormController, :iac_update_attached_form
    get "/iac/labels/:rdid", IACController, :iac_get_labels_of_raw_document
    get "/iac/labels", IACController, :iac_get_labels
    get "/iac/label", IACController, :iac_get_label
    post "/iac/labels", IACController, :iac_commit_labels
    put "/iac/labels", IACController, :iac_put_labels
    post "/iac/ses/form", IACSESController, :iac_ses_post_form
    get "/iac/:id", ApiController, :iac_show_document
    get "/iac/:id/forcereset", ApiController, :iac_reset
    post "/iac/:id/setup", ApiController, :iac_setup
    post "/iac/:id/save", ApiController, :iac_save_fill
    post "/iac/:id/submit", ApiController, :iac_submit_fill
    post "/iac/:id/genpdf", ApiController, :iac_generate_pdf
    post "/iac/:id/field", ApiController, :iac_add_field
    put "/iac/:id/field/:fieldid", ApiController, :iac_update_field
    get "/iac/:id/fields", ApiController, :iac_get_fields
    get "/iac/:id/requestor_fields", ApiController, :iac_get_fields_requestor
    delete "/iac/:id/field/:fid", ApiController, :iac_delete_field
    post "/iac/:id/signature", ApiController, :iac_add_signature

    delete "/iac/signatures/", ApiController, :iac_delete_signature

    get "/dproxy/:filename", ApiController, :document_proxy
    get "/completion/:did", ApiController, :get_completion
    get "/requestor/customized/doc/:id", ApiController, :get_iac_prefilled_doc

    post "/esign/consent", ApiController, :post_esign_consent
    get "/esign/consent/:rid", ApiController, :get_esign_consent

    # Recipients API
    get "/assignments", ApiController, :assignments_info
    get "/assignments/:id", ApiController, :get_assignment_with_id
    post "/assignment/archive", ApiController, :assignment_archive
    put "/assignment/:id/unarchive", ApiController, :requestor_assignment_unarchive
    post "/assignment/checklist/create", ApiController, :recipient_new_assignments
    post "/assignment/unsend", ApiController, :assignment_unsend
    post "/recipient/:id/assignments/unsend", ApiController, :recipient_all_assignments_unsend
    get "/assignment/archive", ApiController, :archived_assignments
    post "/filerequest/:id/missing", ApiController, :recipient_missing_filerequest
    post "/filerequest/:id/manual", ApiController, :requestor_manual_request_upload
    post "/filerequest/:id", ApiController, :recipient_upload_filerequest
    delete "/filerequest/:id", ApiController, :recipient_delete_filerequest
    post "/task/:tid/confirmation/:aid", ApiController, :recipient_upload_confirmation
    delete "/complete/item", ApiController, :requestor_delete_complete_item

    post "/filerequest/:id/save", ApiController, :recipient_save_filerequest
    put "/filerequest/:pid/edit", ApiController, :recipient_edit_filerequest
    post "/filerequest/:reqid/uploaded/:id/submit", ApiController, :recipient_submit_filerequest
    post "/extra/requests/:id", ApiController, :recipient_upload_additional_requests
    put "/filerequest/:pid/track/expiration", DocumentController, :add_expiration_info
    put "/document/:id/return/expire", DocumentController, :return_expired_document

    post "/form", FormController, :create_form_for_contents
    post "/form/:form_id/:contents_id/prefill", FormController, :prefill_form_for_contents
    post "/form/unsend/:assignment_id/:form_id", FormController, :unsend_form

    get "/form/:form_id", FormController, :get_form_by_id
    get "/form-submission/:assignment_id/:form_id", FormController, :handle_get_form_submission
    post "/form-submission", FormController, :create_form_submission
    delete "/form-submission", FormController, :handle_delete_form_submission
    # post "/forms", FormController, :get_forms

    post "/datarequest/:id", ApiController, :recipient_fillin_datarequest
    post "/taskrequest", ApiController, :recipient_done_taskrequest
    post "/document/:id", ApiController, :recipient_upload_document
    put "/checklist/edit/:id", ApiController, :recipient_edit_checklist
    post "/mutiple/requests/:id", ApiController, :recipient_upload_multiple_files

    # Requestor API
    get "/checklists", ApiController, :requestor_checklists
    get "/checklist/:id", ApiController, :requestor_checklist_with_id
    delete "/checklist/:id", ApiController, :requestor_delete_checklist
    put "/checklist/:id", ApiController, :requestor_put_checklist
    put "/checklist/archive/:id", ApiController, :requestor_archive_checklist
    post "/checklist", ApiController, :requestor_new_checklist
    post "/checklist/remind/", ApiController, :remind_now_checklist_v2
    post "/direct/send/recipient/:id", ApiController, :direct_send_templates
    post "/direct/send/checklist/:cid/recipient/:rid", ApiController, :direct_send_checklist
    post "/setup/rsd/document/:docId/recipient/:rid", ApiController, :setup_template_for_rsd

    put "/requestor/:id/set-admin-notify", UserController, :toggle_admin_notifications
    put "/requestor/:id/set-weekly-digest", UserController, :toggle_weekly_digest
    # [Hack] Crimson support for etag fill
    # https://bugs.internal.boilerplate.co/issues/8289
    post "/iac/ses/fill", IACSESController, :iac_ses_fill
    get "/iac/ses/targets/:cid", IACSESController, :iac_ses_targets

    post "/assignment/email/notification",
         UserController,
         :assignment_completion_email_notification
    post "/document/update/email/notification",
         UserController,
         :requestor_document_update_email_notification

    # Notifications
    # tested APIs
    get "/notifications/unread", NotificationController, :get_unread_count
    get "/notifications", NotificationController, :get_notifications
    get "/notification/:id/details", NotificationController, :get_notifications_details
    put "/notification/:id/markread", NotificationController, :mark_notification_read
    put "/notification/:id/archive", NotificationController, :archive_notification

    # Billing metrics
    # Tested APIs
    get "/company/:id/billing/metrics", BillingMetrics, :users_billing_metrics
    post "/company/set-file-retention", BillingMetrics, :set_file_retention

    # Document tags
    #    Tested APIs
    get "/company/:id/tags", DocumentTagController, :get_tags
    post "/company/:id/tags", DocumentTagController, :add_tag
    get "/document-tag/:id", DocumentTagController, :get_tag_by_id
    #    Not Tested APIs

    # Dashboard API
    post "/dashboard", ApiController, :requestor_dashboard
    post "/metadashboard", ApiController, :requestor_dashboard_meta
    post "/dashboard/:rid", ApiController, :requestor_dashboard_for_recipient

    get "/filerequest/:id", ApiController, :requestor_filerequest_with_id
    post "/review/return", ApiController, :requestor_review_return
    post "/review/accept", ApiController, :requestor_review_accept
    get "/reviews", ApiController, :requestor_reviews
    get "/reviews/contents/:cid", ReviewController, :requestor_reviews_contents
    get "/reviews-paginated", ReviewController, :requestor_reviews
    get "/lookup/remaining/reviews/:aid", ApiController, :requestor_lookup_remaining_reviews
    get "/lookup/reviews/pending", ApiController, :lookup_requestor_pending_reviews
    put "/review/assignment/:aid/progress", ApiController, :requestor_review_assignment_lock

    post "/assignment", ApiController, :requestor_new_assignment

    post "/contents", ApiController, :requestor_new_contents
    put "/contents/:id", ApiController, :requestor_put_contents
    get "/contents/:id", ApiController, :requestor_get_contents_by_id
    get "/contents/:rid/:pid", ApiController, :requestor_get_contents
    post "/contents/:id/customize", ApiController, :requestor_customize_document
    delete "/contents/:id/customize", ApiController, :requestor_reset_customize_document
    delete "/contents/:id", ApiController, :requestor_delete_contents
    post "/contents/:id/commit", ApiController, :requestor_commit_rsds

    post "/documentrequest", ApiController, :requestor_new_document_request

    get "/templates", DocumentController, :requestor_templates
    get "/template/:id", DocumentController, :requestor_template_with_id
    delete "/template/:id", DocumentController, :requestor_delete_template
    put "/template/:id", DocumentController, :requestor_put_template
    put "/template/archive/:id", DocumentController, :requestor_archive_template
    put "/template/:id/substitute/file", DocumentController, :requestor_substitute_template
    post "/template/:id/reset", DocumentController, :requestor_template_reset
    put "/template-raw/:id", DocumentController, :requestor_update_raw_doc
    post "/template", DocumentController, :requestor_new_template
    post "/template/:id/manual", ApiController, :requestor_manual_document_upload
    post "/template/read", ApiController, :requestor_read_info

    get "/recipients-paginated", RecipientController, :requestor_recipients_paginated

    post "/recipient/:id/data/filter", RecipientController, :requestor_recipient_data_with_filter

    post "/recipient/:id/data/form", RecipientController, :requestor_recipient_data_make_form

    post "/recipient/:id/data/verifyform",
         RecipientController,
         :requestor_recipient_data_verify_form

    put "/recipient/:id/data/form", RecipientController, :requestor_recipient_data_put_form
    put "/recipient/hide/:id", RecipientController, :requestor_hide_recipient
    put "/recipient/show/:id", RecipientController, :requestor_show_recipient
    put "/recipient/restore/:id", RecipientController, :handle_recipient_restore
    #
    get "/recipient/:id/cabinet", CabinetController, :show
    post "/recipient/:id/cabinet", CabinetController, :create
    delete "/recipient/:id/cabinet/:cid", CabinetController, :delete
    post "/recipient/:rid/cabinet/:cid/replace", CabinetController, :update

    # APIs need to have tests after this line!
    pipe_through [:requestor_only]

    get "/recipient/:id/data", RecipientController, :requestor_recipient_data
    post "/recipient/:id/data", RecipientController, :requestor_new_recipient_data

    post "/recipient/:id/data/label/history",
         RecipientController,
         :requestor_recipient_label_history

    put "/recipient/:id", RecipientController, :requestor_put_recipient
    get "/recipient", RecipientController, :requestor_recipient_exists
    get "/recipients", RecipientController, :requestor_recipients
    get "/recipients/google", IntegrationController, :google_contacts_list
    get "/recipient/:id", RecipientController, :requestor_recipient_with_id
    post "/recipient", RecipientController, :requestor_new_recipient
    post "/recipient/bulk", RecipientController, :requestor_bulk_new_recipient
    delete "/recipient/:id", RecipientController, :requestor_delete_recipient

    pipe_through [:internal_only]
    post "/internal/weeklydigest", ApiController, :do_weekly_digest_debug_test
  end

  scope "/n/api/v2", BoilerPlateWeb do
    pipe_through [:api, :auth]

    post "/dashboard", ApiController, :requestor_dashboard_v2
  end

  scope "/", BoilerPlateWeb do
    pipe_through [:browser, :auth]

    get "/internal/admin", InternalController, :instance_admin
    post "/internal/notification", InternalController, :instance_new_notification
    post "/internal/new/coupon", InternalController, :instance_newcoupon
    post "/internal/new/paymentplan", InternalController, :instance_newpaymentplan

    get "/internal/tmplmover", InternalController, :internal_template_mover
    post "/internal/tmplmover", InternalController, :internal_do_template_mover

    get "/internal/company/:cid/force_trial_expiration",
        InternalController,
        :instance_company_expire_trial

    get "/internal/company/:cid/mandate_mfa",
        InternalController,
        :instance_company_mandate_mfa

    get "/internal/newco", InternalController, :instance_new_co
    get "/internal/modco", InternalController, :instance_mod_co
    get "/internal/users", InternalController, :instance_users
    get "/internal/requestors", InternalController, :instance_requestors
    post "/internal/impersonate", InternalController, :impersonate_user
    get "/internal/force_verify/:iid", InternalController, :force_verify_user
    get "/internal/force_disable_2fa/:iid", InternalController, :force_disable_2fa
    get "/internal/askrevoke/:reqid", InternalController, :revoke_requestor
    get "/internal/askreinstate/:reqid", InternalController, :revoke_requestor
    get "/internal/revoke/:reqid", InternalController, :do_revoke_requestor
    get "/internal/reinstate/:reqid", InternalController, :do_reinstate_requestor
    post "/internal/newco", InternalController, :do_instance_new_co
    post "/internal/modco", InternalController, :do_instance_mod_co

    get "/midlogin", UserController, :midlogin
    get "/recipientDeleted", StormwindController, :recipient_deleted
    get "/user", UserController, :show_user

    # downloaders
    get "/document/:aid/:did/download", DocumentController, :assigned_raw_document_download
    get "/completeddocument/:aid/:did/download", DocumentController, :completed_document_download
    get "/completedchecklist/:aid/download", DocumentController, :api_download_completed_checklist
    get "/checklists/recipient/:rid/download", DocumentController, :api_download_recipient_checklists

    get "/customized/document/:aid/:did/download",
        DocumentController,
        :requestor_customized_doc_download

    get "/completedrequest/:aid/:did/download/:type",
        DocumentController,
        :completed_request_download

    get "/rawdocument/:did/download", DocumentController, :raw_document_download
    get "/reviewdocument/:did/download/:type", DocumentController, :review_document_download
    get "/reviewrequest/:did/download/:type", DocumentController, :review_request_download

    get "/package/customize/:cid/:rid/:rsdid/download",
        DocumentController,
        :customize_rsd_download

    get "/iac/:tid/download", DocumentController, :download_base_iac_doc
    get "/user/:uid/storage/:cid/download", DocumentController, :cabinet_download

    pipe_through :internal_only
    get "/internal/stats", InternalController, :show_statistics
    get "/internal/timer", InternalController, :timer_dump
    get "/iac/:tid/export", IACController, :export_iac
  end

  def cisa_messages() do
    [
      "malformed URI \"%NETHOOD%\"",
      "malformed URI \"%uff0e%uff0e\""
    ]
  end

  def check_restrict(:recipient, claims) do
    cond do
      claims == nil ->
        %{id: "N/A", company_id: -1, company_name: "N/A", err: "no_claims"}

      Map.has_key?(claims, "recipient_id") ->
        recipient = BoilerPlate.Repo.get(BoilerPlate.Recipient, claims["recipient_id"])

        if recipient == nil do
          %{id: "N/A", company_id: -1, company_name: "N/A", err: "bad_recipient_id"}
        else
          company = BoilerPlate.Repo.get(BoilerPlate.Company, recipient.company_id)

          %{
            id: recipient.id,
            company_id: recipient.company_id,
            company_name: company.name,
            err: "none"
          }
        end

      True ->
        %{id: "N/A", company_id: -1, company_name: "N/A", err: "not_restricted"}
    end
  end

  def check_restrict(:requestor, claims) do
    cond do
      claims == nil ->
        %{id: "N/A", company_id: -1, company_name: "N/A", err: "no_claims"}

      Map.has_key?(claims, "requestor_id") ->
        requestor = BoilerPlate.Repo.get(BoilerPlate.Requestor, claims["requestor_id"])

        if requestor == nil do
          %{id: "N/A", company_id: -1, company_name: "N/A", err: "bad_requestor_id"}
        else
          company = BoilerPlate.Repo.get(BoilerPlate.Company, requestor.company_id)

          %{
            id: requestor.id,
            company_id: requestor.company_id,
            company_name: company.name,
            err: "none"
          }
        end

      True ->
        %{id: "N/A", company_id: -1, company_name: "N/A", err: "not_restricted"}
    end
  end

  def handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    if :ets.whereis(:boilerplate_ets_cache) == :undefined do
      :ets.new(:boilerplate_ets_cache, [:named_table])
      my_ip = System.cmd("/usr/bin/curl", ["-s", "httpbin.org/ip"]) |> elem(0) |> Poison.decode!()
      git_hash = System.cmd("#{File.cwd!()}/tools/get_git_status.sh", []) |> elem(0)
      :ets.insert(:boilerplate_ets_cache, {"my_ip", my_ip})
      :ets.insert(:boilerplate_ets_cache, {"git_hash", git_hash})
    end

    subject_line = "CRASH: #{inspect(reason)}"

    user =
      if BoilerPlate.Guardian.Plug.current_resource(conn) != nil do
        BoilerPlate.Guardian.Plug.current_resource(conn)
        |> Map.put(
          :recipient_restrict,
          check_restrict(:recipient, BoilerPlate.Guardian.Plug.current_claims(conn))
        )
        |> Map.put(
          :requestor_restrict,
          check_restrict(:requestor, BoilerPlate.Guardian.Plug.current_claims(conn))
        )
      else
        %{
          id: -1,
          email: "N/A",
          name: "Not Logged In",
          recipient_restrict: %{id: "N/A", company_id: -1, company_name: "N/A", err: "no_res"},
          requestor_restrict: %{id: "N/A", company_id: -1, company_name: "N/A", err: "no_res"}
        }
      end

    headers = [
      {
        "X-Boilerplate-Deploy-Key",
        "9f7898513007ca14ed813222532d34204f51895cd7f4928ab0df33d0d413e27a"
      },
      {"Content-Type", "application/json"}
    ]

    is_csrf = reason.__struct__ == Plug.CSRFProtection.InvalidCSRFTokenError
    is_cisa = reason.__struct__ == ArgumentError and reason.message in cisa_messages()

    should_file =
      not is_cisa and not is_csrf and not (reason.__struct__ == Phoenix.Router.NoRouteError)

    conn = fetch_session(conn)

    guardian_claims = Guardian.Plug.current_claims(conn)

    guardian_claims =
      if guardian_claims == nil do
        ""
      else
        for {k, v} <- guardian_claims, do: "#{k}: #{v}\n"
      end

    my_ip = :ets.lookup(:boilerplate_ets_cache, "my_ip") |> Enum.at(0) |> elem(1)

    git_hash =
      :ets.lookup(:boilerplate_ets_cache, "git_hash") |> Enum.at(0) |> elem(1) |> String.trim()

    nomad_allocation_id = System.get_env("NOMAD_ALLOC_ID", "not_in_nomad")
    nomad_image = System.get_env("BOILERPLATE_IMAGE_HASH", "not_in_nomad")
    redmine_ticket = System.get_env("REDMINE_TICKET", "none")
    session_id = conn |> Plug.Conn.get_session(:session_id)

    session_log =
      with {:ok, d} <-
             BoilerPlate.DashboardCache.get_session_log(:dashboard_cache, session_id, true),
           {:ok, session_log} <- d do
        session_log
      else
        _ -> []
      end

    crash_data = %{
      timestamp: "#{DateTime.utc_now() |> Timex.format!("{ISOdate} {ISOtime}")}",
      subject: subject_line,
      method: conn.method,
      request_path: conn.request_path,
      remote_ip: conn.remote_ip |> Tuple.to_list() |> Enum.join("."),
      host_ip: my_ip["origin"],
      path_info: conn.path_info |> inspect(),
      domain: Application.get_env(:boilerplate, :boilerplate_domain),
      kind: kind,
      user: %{
        name: user.name,
        email: user.email,
        id: user.id,
        recipient_restrict: user.recipient_restrict,
        requestor_restrict: user.requestor_restrict
      },
      sw_version: Application.get_env(:boilerplate, :version),
      image_hash: nomad_image,
      allocation_id: nomad_allocation_id,
      redmine_ticket: redmine_ticket,
      git_hash: git_hash,
      iac_profile: Application.get_env(:boilerplate, :iac_profile),
      reason: inspect(reason),
      stack_traces: for(i <- stack, do: inspect(i)),
      assigns: for(i <- conn.assigns, do: inspect(i)),
      params: for(i <- conn.params, do: inspect(i)),
      headers: for(i <- conn.req_headers, do: inspect(i)),
      session_info: for({k, v} <- Plug.Conn.get_session(conn), do: "#{k}: #{v}"),
      guardian_claim: guardian_claims,
      session_id: session_id,
      session_log: session_log
    }

    final_crash_data = %{
      environment: "new",
      data: crash_data
    }

    cond do
      should_file and Application.get_env(:boilerplate, :redmine_enabled) == true and
          FunWithFlags.enabled?(:automatic_bug_filling) ->
        body = Poison.encode!(final_crash_data)

        id =
          case HTTPoison.post(
                 "https://service-deploy-cli.nomad.boilerplate.co/appcrash",
                 body,
                 headers
               ) do
            {:ok, xx} ->
              result = Poison.decode!(xx.body)
              inspect(result["issue"]["id"])

            _ ->
              "ERROR_DIDNT_FILE"
          end

        if Application.get_env(:boilerplate, :boilerplate_environment) == :dev do
          html(
            conn,
            "<h1>Boilerplate has encountered an issue</h1>Filed as <a href=\"https://bugs.boilerplate.co/issues/#{id}\">##{id}</a>"
          )
        else
          html(
            conn,
            "<h1>Boilerplate has encountered an issue</h1>This has been routed to both our engineers and our support department. Please use ##{id} in any communication if you reach out to support.<br \>Thank you for your patience."
          )
        end

      is_csrf ->
        IO.puts("CSRF ERROR detected")

        conn
        |> put_layout({BoilerPlateWeb.LayoutView, "app.html"})
        |> put_view(BoilerPlateWeb.ErrorView)
        |> render("csrf_expired.html")

      Application.get_env(:boilerplate, :boilerplate_environment) == :dev ->
        IO.puts(:stderr, inspect(final_crash_data))
        text(conn, inspect(final_crash_data))

      True ->
        conn
    end
  end

  def file_iac_bug(fillwrap, tmp_pdf_path, tmp_json_path, tmp_final_path, cmd_stdout) do
    # IAC fill crashed, let's file a bug.
    url = "https://bugs.boilerplate.co/issues.json"
    upload_url = "https://bugs.boilerplate.co/uploads.json"

    headers = [
      {"X-Redmine-API-Key", "a1f7b73cc9f0e73d9577deccd72bbc7252a61a0f"},
      {"Content-Type", "application/json"}
    ]

    upload_headers = [
      {"X-Redmine-API-Key", "a1f7b73cc9f0e73d9577deccd72bbc7252a61a0f"},
      {"Content-Type", "application/octet-stream"}
    ]

    # Upload the files first.
    pdf_token =
      case HTTPoison.post(
             "#{upload_url}?filename=the_pdf.pdf",
             {:file, tmp_pdf_path},
             upload_headers
           ) do
        {:ok, xx} ->
          result = Poison.decode!(xx.body)
          IO.inspect(result)
          result["upload"]["token"]

        _ ->
          IO.inspect("Failed to upload the PDF")
          :invalid_token
      end

    IO.inspect("pdf token: #{pdf_token}")

    bp01_token =
      case HTTPoison.post(
             "#{upload_url}?filename=the_bp01.json",
             {:file, tmp_json_path},
             upload_headers
           ) do
        {:ok, xx} ->
          result = Poison.decode!(xx.body)
          IO.inspect(result)
          result["upload"]["token"]

        _ ->
          IO.inspect("Failed to upload the bp01")
          :invalid_token
      end

    IO.inspect("bp01 token: #{bp01_token}")

    uploads =
      cond do
        pdf_token != :invalid_token and bp01_token != :invalid_token ->
          [
            %{token: pdf_token, filename: "the_pdf.pdf", content_type: "application/pdf"},
            %{token: bp01_token, filename: "the_bp01.json", content_type: "application/json"}
          ]

        pdf_token == :invalid_token ->
          [
            %{token: bp01_token, filename: "the_bp01.json", content_type: "application/json"}
          ]

        bp01_token == :invalid_token ->
          [
            %{token: pdf_token, filename: "the_pdf.pdf", content_type: "application/pdf"}
          ]

        True ->
          []
      end

    upload_text =
      cond do
        pdf_token != :invalid_token and bp01_token != :invalid_token ->
          "Please fine attached PDF and bp-01 files."

        pdf_token == :invalid_token ->
          "Please fine attached bp-01 file, the PDF failed to upload."

        bp01_token == :invalid_token ->
          "Please fine attached PDF file, the bp-01 failed to upload."

        True ->
          "Neither the PDF nor the bp01 was able to be uploaded."
      end

    git_version = System.cmd("#{File.cwd!()}/tools/get_git_status.sh", []) |> elem(0)
    nomad_allocation_id = System.get_env("NOMAD_ALLOC_ID", "not_in_nomad")
    nomad_image = System.get_env("BOILERPLATE_IMAGE_HASH", "not_in_nomad")

    version_info =
      "app: #{Application.get_env(:boilerplate, :version)}\napi: 0.0.0\ngit: #{git_version}\nnomad: #{nomad_allocation_id}\ntag=#{nomad_image}"

    description = "Hello!

IACFill crashed on UTC #{DateTime.utc_now() |> Timex.format!("{ISOdate} {ISOtime}")}

Version info:
#{version_info}

#{upload_text} The full command invocation was:

```
#{fillwrap} #{tmp_pdf_path} #{tmp_json_path} #{tmp_final_path}
```

which resulted in the following combined `stdout` and `stderr` output:

```
#{cmd_stdout}
```
"

    body =
      Poison.encode!(%{
        issue: %{
          project_id: 1,
          tracker_id: 4,
          subject:
            "IACFill Crash UTC #{DateTime.utc_now() |> Timex.format!("{ISOdate} {ISOtime}")}",
          description: description,
          assigned_to_id: 5,
          uploads: uploads,
          custom_fields: [
            %{value: "Auto-filed", name: "Keywords", id: 3}
          ]
        }
      })

    id =
      case HTTPoison.post(url, body, headers) do
        {:ok, xx} ->
          result = Poison.decode!(xx.body)
          result["issue"]["id"]

        _ ->
          "ERROR_DIDNT_FILE"
      end

    IO.inspect("IACbug ID: #{id}")
  end

  # Other scopes may use custom stacks.
  # scope "/api", BoilerPlateWeb do
  #   pipe_through :api
  # end
end
