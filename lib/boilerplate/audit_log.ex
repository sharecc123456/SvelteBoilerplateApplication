require Logger

defmodule BoilerPlate.AuditLog do
  ## Asyncicity

  def failure_map() do
    [
      {:assignment_archive_failed, "package.assignment.archive_failure",
       "assignment archiving failed",
       [:company_id, :recipient_id, :package_id, :assignment_id, :reason]},
      {:assignment_unarchive_failed, "package.assignment.unarchive_failure",
       "assignment unarchiving failed",
       [:company_id, :recipient_id, :package_id, :assignment_id, :reason]},
      {:assignment_delete_failed, "package.assignment.delete_failure",
       "deleting assignment failed",
       [:company_id, :recipient_id, :package_id, :assignment_id, :reason]},
      {:contents_new_failure, "package.contents.new_failure", "creating package contents failed",
       [:company_id, :recipient_id, :package_id, :reason]},
      {:contents_rsd_download_failure, "package.contents.rsd_download_failure",
       "download an rsd to customize failed",
       [:company_id, :recipient_id, :contents_id, :document_id, :reason]},
      {:contents_rsd_upload_failure, "package.contents.rsd_customize_failure",
       "upload customized rsd failed",
       [:company_id, :recipient_id, :contents_id, :document_id, :reason]},
      {:contents_request_add_failure, "package.contents.request_add_failure",
       "adding a request to contents failed",
       [:company_id, :recipient_id, :contents_id, :request_name, :reason]},
      {:contents_request_delete_failure, "package.contents.request_remove_failure",
       "adding a request to contents failed",
       [:company_id, :recipient_id, :contents_id, :request_name, :request_id, :reason]},
      {:contents_document_add_failure, "package.contents.document_add_failure",
       "adding a document to contents failed",
       [:company_id, :contents_id, :document_id, :reason]},
      {:contents_document_delete_failure, "package.contents.document_remove_failure",
       "adding a document to contents failed",
       [:company_id, :contents_id, :document_id, :reason]},
      {:contents_extra_failure, "package.contents.document_extra_failure",
       "adding an extra to contents failed",
       [:company_id, :contents_id, :name, :description, :reason]},
      {:recipient_document_download_failure, "recipient.document.download_failure",
       "downloading an assigned raw document",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :document_id, :reason]},
      {:recipient_document_upload_failure, "recipient.document.upload_failure",
       "uploading an assigned raw document",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :raw_id]},
      {:recipient_request_upload_failure, "recipient.request.upload_failure",
       "uploading an assigned request",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id]},
      {:recipient_request_fillin_failure, "recipient.request.fillin_failure",
       "filling an assigned textual request",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id, :fillin_string]},
      {:recipient_request_task_failure, "recipient.request.task_failure",
       "Marking task request as done",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id]},
      {:recipient_request_missing_failure, "recipient.request.missing_failure",
       "marking as missing a request",
       [
         :company_id,
         :assignment_id,
         :contents_id,
         :recipient_id,
         :request_id,
         :missing_reason,
         :reason
       ]},
      {:review_document_approve_failure, "review.document.approve_failure",
       "failed approving document",
       [:company_id, :document_id, :raw_document_id, :recipient_id, :reason]},
      {:review_document_return_failure, "review.document.return_failure", "approving document",
       [:company_id, :document_id, :raw_document_id, :recipient_id, :return_comments, :reason]},
      {:review_request_return_failure, "review.request.return_failure",
       "failed returnning requesto",
       [
         :company_id,
         :request_id,
         :request_completion_id,
         :recipient_id,
         :return_comments,
         :reason
       ]},
      {:iac_ses_targets_failed, "iac.ses.targets_failure", "iac ses targets",
       [:requestor_id, :checklist_id, :reason]},
      {:review_request_approve_failure, "review.request.approve_failure",
       "failed approving request",
       [:company_id, :request_id, :request_completion_id, :recipient_id, :reason]}
    ]
  end

  def basic_map() do
    [
      {:assignment_archive, "package.assignment.archive", "archive assignment",
       [:company_id, :recipient_id, :package_id, :assignment_id]},
      {:assignment_unarchive, "package.assignment.unarchive", "unarchive assignment",
       [:company_id, :recipient_id, :package_id, :assignment_id]},
      {:assignment_delete, "package.assignment.delete", "delete assignment",
       [:company_id, :recipient_id, :package_id, :assignment_id]},
      {:contents_new, "package.contents.new", "creating package contents",
       [:company_id, :recipient_id, :package_id, :contents_id]},
      {:contents_rsd_download, "package.contents.rsd_download", "download an rsd to customize",
       [:company_id, :recipient_id, :contents_id, :document_id]},
      {:contents_rsd_upload, "package.contents.rsd_customize", "upload customized rsd",
       [:company_id, :recipient_id, :contents_id, :document_id, :customized_id, :final_path]},
      {:contents_rsd_nordc, "package.contents.rsd_nocustomize", "upload customized rsd",
       [:company_id, :recipient_id, :contents_id, :document_id, :customized_id]},
      {:contents_request_add, "package.contents.request_add", "adding a request to contents",
       [:company_id, :recipient_id, :contents_id, :request_name, :request_id]},
      {:contents_request_delete, "package.contents.request_remove",
       "adding a request to contents",
       [:company_id, :recipient_id, :contents_id, :request_name, :request_id]},
      {:contents_document_add, "package.contents.document_add", "adding a document to contents",
       [:company_id, :contents_id, :document_id]},
      {:contents_document_delete, "package.contents.document_remove",
       "adding a document to contents", [:company_id, :contents_id, :document_id]},
      {:contents_extra, "package.contents.document_extra", "adding an extra to contents",
       [:company_id, :contents_id, :name, :description, :final_path, :document_id]},
      {:recipient_document_download, "recipient.document.download",
       "downloading an assigned raw document",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :document_id]},
      {:recipient_document_upload, "recipient.document.upload",
       "uploading an assigned raw document",
       [
         :company_id,
         :assignment_id,
         :contents_id,
         :recipient_id,
         :final_path,
         :raw_id,
         :document_id
       ]},
      {:recipient_request_upload, "recipient.request.upload", "uploading an assigned request",
       [
         :company_id,
         :assignment_id,
         :contents_id,
         :recipient_id,
         :final_path,
         :request_id,
         :request_completion_id
       ]},
      {:recipient_request_fillin, "recipient.request.fillin",
       "filling an assigned textual request",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id, :fillin_string]},
      {:recipient_request_task, "recipient.request.task", "Marking task request as done",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id]},
      {:recipient_request_missing, "recipient.request.missing", "marking as missing a request",
       [:company_id, :assignment_id, :contents_id, :recipient_id, :request_id, :missing_reason]},
      {:review_document_approve, "review.document.approve", "approving document",
       [:company_id, :document_id, :raw_document_id, :recipient_id]},
      {:review_document_return, "review.document.return", "returnning document",
       [:company_id, :document_id, :raw_document_id, :recipient_id, :return_comments]},
      {:review_request_return, "review.request.return", "returnning requesto",
       [:company_id, :request_id, :request_completion_id, :recipient_id, :return_comments]},
      {:review_request_approve, "review.request.approve", "approving request",
       [:company_id, :request_id, :request_completion_id, :recipient_id]},
      {:iac_ses_targets, "iac.ses.targets", "iac ses targets",
       [:requestor_id, :checklist_id, :response_type]},
      {:accept_tos, "user.terms.accept", "accepted ToS", []},
      {:resend_verify_email, "user.verify_email.resend", "resent email verification", []},
      {:verify_email, "user.verify_email", "email verification", []}
    ]
  end

  defp is_failure?(key) do
    key in (failure_map() |> Enum.map(&(&1 |> elem(0))))
  end

  defp is_basic?(key) do
    key in (basic_map() |> Enum.map(&(&1 |> elem(0))))
  end

  defp get_from(key, map) do
    map
    |> Enum.filter(&(elem(&1, 0) == key))
    |> Enum.at(0)
  end

  def audit(key, arg) do
    # IO.inspect(Task.start fn -> do_audit(key, arg) end)
    cond do
      is_failure?(key) -> do_audit_failure(get_from(key, failure_map()), arg)
      is_basic?(key) -> do_audit_basic(get_from(key, basic_map()), arg)
      True -> do_audit(key, arg)
    end
  end

  def audit(key) do
    audit(key, %{})
  end

  def audit_identify(user) do
    Segment.Analytics.identify(user.id, %{
      email: user.email,
      id: user.id,
      name: user.name
    })
  end

  ## Tools

  def segment_track(event, userid \\ "0", properties \\ %{}) do
    if Application.get_env(:boilerplate, :boilerplate_environment) != :test do
      %Segment.Analytics.Track{userId: userid, event: event, properties: properties}
      |> Segment.Analytics.track()
    end
  end

  def fmt_user(user) do
    "[uid #{user.id} email #{user.email}]"
  end

  def do_audit_failure(failure_desc, params) do
    user = params[:user]
    {_key, segment_key, action, ps} = failure_desc
    data = for {k, v} <- Map.take(params, ps), do: "#{k} = #{v} "

    Logger.warn("#{fmt_user(user)} #{action} failed: #{data}")

    segment_track(segment_key, user.id, Map.take(params, ps))
  end

  def do_audit_basic(basic_desc, params) do
    user = params[:user]
    {_key, segment_key, action, ps} = basic_desc
    logtxt = for {k, v} <- Map.take(params, ps), do: "#{k} = #{v} "

    Logger.info("#{fmt_user(user)} #{action} basically: #{logtxt}")

    segment_track(segment_key, user.id, Map.take(params, ps))
  end

  ###
  # Generic Documents
  ###

  def do_audit(:generic_upload_failure, params = %{user: user, reason: reason}) do
    Logger.warn(
      "#{fmt_user(user)} Tried to upload a template (#{params[:name] || "unknown"}), but failed due to reason #{reason}"
    )

    segment_track("document.generic.upload_failure", user.id, %{
      name: params[:name] || "",
      description: params[:description] || "",
      reason: reason
    })
  end

  def do_audit(
        :generic_upload_success,
        params = %{user: user, name: name, description: description, final_path: final_path}
      ) do
    Logger.info(
      "#{fmt_user(user)} New document template: name '#{name}' desc '#{description}' => final_path: #{final_path}"
    )

    segment_track("document.generic.upload_success", user.id, %{
      name: name,
      description: description,
      final_path: final_path,
      company_id: params[:company_id]
    })
  end

  ###
  # Recipient Specific Documents
  ###

  def do_audit(:rsd_upload_failure, params = %{user: user, reason: reason}) do
    Logger.warn(
      "#{fmt_user(user)} Tried to upload a RSD (#{params[:name] || "unknown"}), but failed due to reason #{reason}"
    )

    segment_track("document.rsd.upload_failure", user.id, %{
      name: params[:name] || "",
      description: params[:description] || "",
      reason: reason
    })
  end

  def do_audit(
        :rsd_upload_success,
        params = %{user: user, name: name, description: description, final_path: final_path}
      ) do
    Logger.info(
      "#{fmt_user(user)} New document RSD: name '#{name}' desc '#{description}' => final_path: #{final_path}"
    )

    segment_track("document.rsd.upload_success", user.id, %{
      name: name,
      description: description,
      final_path: final_path,
      company_id: params[:company_id]
    })
  end

  ###
  # Document Management
  ###

  def do_audit(:generic_edit_failure, %{user: user, reason: reason, docid: did}) do
    Logger.warn(
      "#{fmt_user(user)} tried edit_template did #{did}, but can't because reason #{reason}"
    )

    segment_track("document.edit.failure", user.id, %{
      reason: reason,
      document_id: did
    })
  end

  def do_audit(:generic_edit_success, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Updated template #{params[:docid]} (#{params[:name]}}) <- (#{params[:new_name]}); (#{params[:description]}) <- (#{params[:new_description]})"
    )

    segment_track(
      "document.edit.success",
      user.id,
      Map.take(params, [:docid, :name, :new_name, :description, :new_description])
    )
  end

  def do_audit(:generic_delete_success, params) do
    user = params[:user]
    Logger.info("#{fmt_user(user)} Deleted template did #{params[:document_id]}")

    segment_track("document.delete.success", user.id, Map.take(params, [:document_id]))
  end

  def do_audit(:generic_delete_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} delete_template did #{params[:document_id]} can't delete reason #{params[:reason]}"
    )

    segment_track("document.delete.failure", user.id, Map.take(params, [:document_id, :reason]))
  end

  ###
  # Packages
  ###

  def do_audit(:package_create_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Attempting to create a package but can't due to reason #{params[:reason]}"
    )

    segment_track(
      "package.create.failure",
      user.id,
      Map.take(params, [:company_id, :name, :description, :reason])
    )
  end

  def do_audit(:package_create, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Created package id #{params[:package_id]}, name #{params[:name]}"
    )

    segment_track(
      "package.create",
      user.id,
      Map.take(params, [:company_id, :name, :description, :package_id])
    )
  end

  def do_audit(:package_delete, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Deleting package #{params[:package].title} was id #{params[:package].id}"
    )

    segment_track("package.delete", user.id, Map.take(params, [:package_id, :company_id]))
  end

  def do_audit(:package_delete_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Attempting to delete a package but can't due to reason #{params[:reason]}"
    )

    segment_track(
      "package.create.failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :reason])
    )
  end

  def do_audit(:package_edit, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Edited package #{params[:package_id]}: {#{params[:name]},#{params[:description]}} -> {#{params["new_name"]},#{params[:new_description]}}"
    )

    segment_track(
      "package.edit",
      user.id,
      Map.take(params, [
        :package_id,
        :company_id,
        :name,
        :description,
        :new_name,
        :new_description
      ])
    )
  end

  def do_audit(:package_edit_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Attempting to edit a package but can't due to reason #{params[:reason]}"
    )

    segment_track(
      "package.edit.failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :reason])
    )
  end

  def do_audit(:package_request_add, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Adding request #{params[:request_name]} to package id #{params[:package_id]}"
    )

    segment_track(
      "package.request.add",
      user.id,
      Map.take(params, [:company_id, :package_id, :request_name])
    )
  end

  def do_audit(:package_request_add_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Failed to add request #{params[:request_name]} to package id #{params[:package_id]}, reason: #{params[:reason]}"
    )

    segment_track(
      "package.request.add_failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :request_name, :reason])
    )
  end

  def do_audit(:package_request_delete, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Deleting request #{params[:request_name]} to package id #{params[:package_id]}"
    )

    segment_track(
      "package.request.delete",
      user.id,
      Map.take(params, [:company_id, :package_id, :request_name])
    )
  end

  def do_audit(:package_request_delete_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Failed to delete request #{params[:request_name]} to package id #{params[:package_id]}, reason: #{params[:reason]}"
    )

    segment_track(
      "package.request.delete_failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :request_name, :reason])
    )
  end

  def do_audit(:package_document_add, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Adding document #{params[:document_id]} to package #{params[:package_id]}"
    )

    segment_track(
      "package.document.add",
      user.id,
      Map.take(params, [:company_id, :package_id, :document_id])
    )
  end

  def do_audit(:package_document_delete, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Deleting document #{params[:document_id]} from package #{params[:package_id]}"
    )

    segment_track(
      "package.document.delete",
      user.id,
      Map.take(params, [:company_id, :package_id, :document_id])
    )
  end

  def do_audit(:package_document_failure, params) do
    user = params[:user]

    Logger.warn(
      "#{fmt_user(user)} Failed to toggle document #{params[:document_id]} in package #{params[:package_id]}, reason: #{params[:reason]}"
    )

    segment_track(
      "package.document.failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :document_id, :reason])
    )
  end

  def do_audit(:package_adhoc_create, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Created adhoc link for package id #{params[:package_id]}: adhoc identifier: #{params[:adhoc_string]}"
    )

    segment_track(
      "package.adhoc.create",
      user.id,
      Map.take(params, [:company_id, :package_id, :adhoc_string])
    )
  end

  def do_audit(:package_adhoc_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Failed to create adhoc link for package id #{params[:package_id]}, reason: #{params[:reason]}"
    )

    segment_track(
      "package.adhoc.failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :reason])
    )
  end

  def do_audit(:package_duplicate, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Duplicated package id #{params[:package_id]} name #{params[:package_name]} to new id #{params[:new_package_id]}"
    )

    segment_track(
      "package.duplicate",
      user.id,
      Map.take(params, [:company_id, :package_id, :package_name, :new_package_id])
    )
  end

  def do_audit(:package_duplicate_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Failed to duplicate package id #{params[:package_id]} name #{params[:package_name]} because of reason #{params[:reason]}"
    )

    segment_track(
      "package.duplicate.failure",
      user.id,
      Map.take(params, [:company_id, :package_id, :package_name, :reason])
    )
  end

  def do_audit(:package_assignment_new, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} New PackageAssignment #{params[:recipient_name]} <- #{params[:package_name]} by #{params[:requestor_name]} assignemnt_id: #{params[:assignment_id]}"
    )

    segment_track(
      "package.assignment.new",
      user.id,
      Map.take(params, [
        :compny_id,
        :recipient_name,
        :recipient_id,
        :package_id,
        :package_name,
        :contents_id,
        :requestor_id,
        :requestor_name,
        :assignment_id
      ])
    )
  end

  def do_audit(:package_assignment_new_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} New PackageAssignment failed #{params[:recipient_name]} <- #{params[:package_name]} by #{params[:requestor_name]} reason #{params[:reason]}"
    )

    segment_track(
      "package.assignment.new_failure",
      user.id,
      Map.take(params, [
        :compny_id,
        :recipient_name,
        :recipient_id,
        :package_id,
        :package_name,
        :requestor_id,
        :requestor_name,
        :reason
      ])
    )
  end

  ###
  # Registration Management
  ###

  def do_audit(
        :register_attempt,
        params = %{
          company_name: company_name,
          requestor_name: requestor_name,
          email: email,
          promo_code: promo_code,
          plan: plan
        }
      ) do
    Logger.info(
      "Registration attempt (company: #{company_name}, requestor: #{requestor_name} (#{email}), promo/plan: #{promo_code}/#{plan}"
    )

    segment_track("company.register.attempt", 0, params)
  end

  def do_audit(:register_fatal, %{reason: reason}) do
    Logger.error("Unexpected reg_pre: #{reason}")

    segment_track("company.register.fatal", 0, %{reason: reason})
  end

  def do_audit(
        :register_failure,
        params = %{
          company_name: _company_name,
          requestor_name: _requestor_name,
          email: _email,
          promo_code: _promo_code,
          plan: _plan,
          reason_id: reg_pre
        }
      ) do
    Logger.info("Failed registration attempt: #{reg_pre}")

    segment_track("company.register.failure", 0, params)
  end

  def do_audit(:register_success, %{
        company_name: cpname,
        admin_id: admin_id,
        company_id: company_id
      }) do
    Logger.info("Registered new company #{cpname} with admin id #{admin_id}")

    segment_track("company.register.success", admin_id, %{
      company_name: cpname,
      company_id: company_id
    })
  end

  ###
  # Access Management
  ###

  def do_audit(:login_success, %{user: user}) do
    Logger.info("Login success for #{user.name} (id: #{user.id}, email: #{user.email})")

    segment_track("user.login.success", user.id)
  end

  def do_audit(:login_failure, %{email: _email, reason: _reason}) do
    # Do nothing here
  end

  def do_audit(:login_banned, _arg0) do
    Logger.info("Login ban initiated for 5 minutes")

    segment_track("user.login.banned")
  end

  def do_audit(:login_attempt, %{email: email}) do
    Logger.info("Login attempt for email #{email}")

    segment_track("user.login.attempt", 0, %{email: email})
  end

  def do_audit(:logout, user) do
    Logger.info("Logout for #{user.name} (id: #{user.id}, email: #{user.email})")

    segment_track("user.logout.success", user.id)
  end

  def do_audit(:logout_nouser, _arg0) do
    Logger.info("Logout without active, logged-in user")

    segment_track("user.logout.nouser")
  end

  def do_audit(:recipient_invite, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} New recipient invited: #{params[:new_recipient_name]} email: #{params[:email]}, recipient_id: #{params[:recipient_id]}, user_id: #{params[:user_id]}, was new? #{params[:was_new_user]}"
    )

    segment_track(
      "user.recipient.invite",
      user.id,
      Map.take(params, [
        :company_id,
        :recipient_id,
        :was_new_user,
        :user_id,
        :new_recipient_name,
        :email
      ])
    )
  end

  def do_audit(:recipient_invite_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} New recipient invite failed: #{params[:new_recipient_name]} email: #{params[:email]}, reason: #{params[:reason]}"
    )

    segment_track(
      "user.recipient.invite_failure",
      user.id,
      Map.take(params, [:company_id, :new_recipient_name, :email, :reason])
    )
  end

  def do_audit(:recipient_delete, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Deleting recipient #{params[:recipient_name]} (id: #{params[:recipient_id]}, email: #{params[:recipient_email]})"
    )

    segment_track(
      "user.recipient.delete",
      user.id,
      Map.take(params, [:company_id, :recipient_name, :recipient_id, :recipient_email, :user_id])
    )
  end

  def do_audit(:recipient_delete_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Deleting recipient #{params[:recipient_name]} (id: #{params[:recipient_id]}, email: #{params[:recipient_email]}) failed due to reason #{params[:reason]}"
    )

    segment_track(
      "user.recipient.delete_failure",
      user.id,
      Map.take(params, [
        :company_id,
        :recipient_name,
        :recipient_id,
        :recipient_email,
        :user_id,
        :reason
      ])
    )
  end

  def do_audit(:recipient_hide, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Hiding recipient #{params[:recipient_name]} (id: #{params[:recipient_id]}, email: #{params[:recipient_email]})"
    )

    segment_track(
      "user.recipient.hide",
      user.id,
      Map.take(params, [
        :company_id,
        :recipient_name,
        :recipient_id,
        :recipient_email,
        :user_id,
        :reason
      ])
    )
  end

  def do_audit(:recipient_edit, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Edited  recipient id #{params[:recipient_id]} name (#{params[:recipient_name]} <- #{params[:new_name]}) org (#{params[:recipient_org]} <- #{params[:new_org]}) phone_number (#{params[:phone_number]} <- #{params[:new_phone_number]})"
    )

    segment_track(
      "user.recipient.edit",
      user.id,
      Map.take(params, [
        :company_id,
        :recipient_name,
        :recipient_id,
        :new_name,
        :new_org,
        :recipient_org,
        :user_id,
        :phone_number
      ])
    )
  end

  def do_audit(:recipient_edit_failure, params) do
    user = params[:user]

    Logger.info(
      "#{fmt_user(user)} Editing recipient failed id #{params[:recipient_id]} name (#{params[:recipient_name]} <- #{params[:new_name]}) org (#{params[:recipient_org]} <- #{params[:new_org]}) phone_number (#{params[:phone_number]} <- #{params[:new_phone_number]}) reason #{params[:reason]}"
    )

    segment_track(
      "user.recipient.edit_failure",
      user.id,
      Map.take(params, [
        :company_id,
        :recipient_name,
        :recipient_id,
        :new_name,
        :new_org,
        :user_id,
        :phone_number,
        :reason
      ])
    )
  end

  def do_audit(:signatureDel, _arg0) do
    Logger.info("Inside Del signature Api")

    segment_track("user.del_signature")
  end

  def do_audit(:successSignatureDelete, num) do
    Logger.info("#{num} Signature Deleted")

    segment_track("user.success_del_signature", %{rows_deleted: num})
  end

  def do_audit(:signatureDelForbid, _) do
    Logger.info("Forbidden Signature Deleted")

    segment_track("user.forbidden_del_signature", %{})
  end

  def do_audit(:successConvertImage, _arg0) do
    Logger.info("Successfull converted image to pdf")

    segment_track("package.document.success_image_conversion")
  end

  def do_audit(:failureConvertImage, params) do
    Logger.info(
      "Failed to convert image #{params[:filename]} to pdf with error status #{params[:exit_status]}"
    )

    segment_track("package.document.failure_image_conversion", %{
      exit_status: params[:exit_status]
    })
  end

  def do_audit(:successMergePDF, _arg0) do
    Logger.info("Successfull merged pdf files")

    segment_track("package.document.success_merge_pdf")
  end

  def do_audit(:failureMergePDF, params) do
    Logger.info(
      "Failed to merge PDFs into a single pdf #{params[:filepath]} error status #{params[:exit_status]}"
    )

    segment_track("package.document.failure_merge_pdf", %{exit_status: params[:exit_status]})
  end

  def do_audit(:failureAllowAccess, params) do
    user = params[:user]

    Logger.info(
      "#{params[:message]} recipient_company: #{params[:recipient_company_id]}, requestor_company: #{params[:requestor_company_id]},
                doc_id: #{params[:doc_id]}, doc_company: #{params[:doc_company_id]}, recipient_id: #{params[:recipient_id]},
                requestor_id: #{params[:requestor_id]}"
    )

    segment_track(
      "user.document.access_failure",
      user.id,
      Map.take(params, [
        :requestor_company_id,
        :doc_company_id,
        :doc_id,
        :recipient_id,
        :recipient_company_id,
        :doc_id,
        :requestor_id,
        :message
      ])
    )
  end

  ###
  # Catch-all
  ###

  def do_audit(audit_event, _arg0) do
    Logger.error("Unknown audit event #{audit_event}, not emitting it.")

    segment_track("internal.audit.unknown_event", %{event: "#{audit_event}"})
  end
end
