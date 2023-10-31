defmodule BoilerPlate.Mailer do
  use Bamboo.Mailer, otp_app: :boilerplate
end

defmodule BoilerPlate.Email do
  import Bamboo.Email
  require Logger

  defp email_hostname() do
    Application.get_env(:boilerplate, :boilerplate_domain)
  end

  defp email_defaults(email, template, data \\ %{}) do
    email
    |> Bamboo.MailgunHelper.template(template)
    |> Bamboo.MailgunHelper.template_text(true)
    |> Bamboo.MailgunHelper.substitute_variables(%{
      "blptdeliverycheck" => template == "checklistassigned",
      "blptenv" => Application.get_env(:boilerplate, :boilerplate_domain),
      "blptdata" => data
    })
  end

  def login_hash_for(user) do
    user.password_hash
  end

  def should_send_emails?() do
    Application.get_env(:boilerplate, :boilerplate_environment) != :test and
      FunWithFlags.enabled?(:email_sending)
  end

  def register_welcome_email(user, company) do
    new_email(
      to: user.email,
      from: "notifications@boilerplate.co",
      subject: "Boilerplate Account Activation for #{String.trim(user.name)} of #{company.name}",
      text_body: "Dear #{String.trim(user.name)},
          Congratulations on signing up for Boilerplate, online software designed to make repetitive documentation easy!
          Let’s get started now with your first Boilerplate, even if you’re not ready to send it:
            - ** Sign in here ** #{email_hostname()}/ using your email address and password.
            - Upload templates
            - Group them into a package (pause here if you’re not ready to send yet)
            - Create a new user for the recipient(s).  For your first one, you may want to send a test with yourself as the recipient.
            - Assign a package to a recipient
          The recipient will receive an email with your documentation request.  Once they’re done, you’ll get a confirmation email and the dashboard will update with a link to the files for your review.  It’s that easy.
          For technical support questions, please email support@boilerplate.co, or just reply to this email.
          We want you to LOVE using Boilerplate, so please share any feedback or suggestions here: feedback@boilerplate.co
          Thank you,
          The Boilerplate Team
          "
    )
    |> email_defaults("registerwelcome")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      user: "#{String.trim(user.name)}",
      userEmail: user.email,
      link: "#{email_hostname()}"
    })
  end

  def send_register_welcome_email(user, company) do
    if should_send_emails?() do
      register_welcome_email(user, company)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def verification_email(user, _company) do
    new_email(
      to: user.email,
      from: "notifications@boilerplate.co",
      subject: "[Boilerplate] Please Verify Your Email",
      text_body: "Dear #{String.trim(user.name)},
          Congratulations on signing up for Boilerplate, online software designed to make repetitive documentation easy!
          Before we can activate your access, we need to verify your email address. Please click the link below to let us know we have the correct email address:

                #{email_hostname()}/email/verification/#{user.verification_code}

          For technical support questions, please email support@boilerplate.co, or just reply to this email.
          We want you to LOVE using Boilerplate, so please share any feedback or suggestions here: feedback@boilerplate.co
          Thank you,
          The Boilerplate Team
          "
    )
    |> email_defaults("verification")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      user: "#{String.trim(user.name)}",
      userEmail: user.email,
      link: "#{email_hostname()}/email/verification/#{user.verification_code}"
    })
  end

  def send_verification_email(user, company) do
    if should_send_emails?() do
      verification_email(user, company)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  # To be Removed
  def assigned_cordial_email(user, _recipient, package, _company, req) do
    new_email(
      to: user.email,
      from:
        "\"#{req.organization} (#{req.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject: "#{req.organization} (#{req.name}) has sent you #{package.title}",
      text_body: "Greetings"
    )
  end

  def assigned_email(user, recipient, package, company, req, a_note, assign) do
    new_email(
      to: user.email,
      from:
        "\"#{company.name} (#{req.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject:
        "#{package.title} has been sent by #{req.name} of #{company.name} for your completion",
      text_body: "Dear #{String.trim(recipient.name)},
          #{req.name} (#{req.email}) from #{company.name} has sent the following for completion at your earliest convenience:
          #{package.title} (click to open)
          #{BoilerPlate.Package.construct_list_for_email(package)}
          Your actions:
            - Fill out the forms
            - Sign (if required)
            - Save
            - Upload via Boilerplate
            - Review and submit
          Confirmation emails will then be automatically sent to both you and the requestor.
          For questions or support:
          Documentation-related: #{req.email}
          Boilerplate technical help: support@boilerplate.co
          Thank you,
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("checklistassigned", %{
      user_id: user.id,
      assign_id: assign.id
    })
    |> Bamboo.MailgunHelper.substitute_variables(%{
      user: "#{String.trim(recipient.name)}",
      checkName: package.title,
      reqName: req.name,
      reqOrg: company.name,
      reqEmail: req.email,
      append_note: a_note,
      dueDateInfo: get_due_date_info_template(package),
      link: "#{email_hostname()}/user/#{user.id}/login/#{login_hash_for(user)}/"
    })
  end

  def get_due_date_info_template(content) do
    # TODO: check why is due is enforced but the due date is nil
    if content.enforce_due_date == true do
      due_date = content.due_date

      if due_date != nil do
        due_day = due_date.day
        due_month = due_date.month
        due_year = due_date.year

        "The deadline for the checklist is on #{due_day} #{Timex.month_shortname(due_month)}, #{due_year}."
      else
        ""
      end
    else
      ""
    end
  end

  def send_assigned_email(user, recipient, package, company, req, assign, append_note \\ "") do
    if should_send_emails?() do
      # To be Removed?
      if FunWithFlags.enabled?(:hack_cordial, for: company) do
        assigned_cordial_email(user, recipient, package, company, req)
        |> put_header("Reply-To", req.email)
        |> BoilerPlate.Mailer.deliver_now()
      else
        assigned_email(user, recipient, package, company, req, append_note, assign)
        |> put_header("Reply-To", req.email)
        |> BoilerPlate.Mailer.deliver_now()
      end
    end
  end

  def forgot_password_email(user, link) do
    new_email(
      to: user.email,
      from: "notifications@boilerplate.co",
      subject: "[Boilerplate] Forgot Password",
      text_body: "Hello #{user.name},
          You (or someone else) has indicated that you forgot your password for using Boilerplate. If you requested this, please follow the link below to reset your password:
          #{link}

          Have a great day and thank you for using Boilerplate.

          Thanks,
          The Boilerplate Team
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("passwordforgot")
    |> Bamboo.MailgunHelper.substitute_variables(%{name: user.name, reslink: link})
  end

  def send_forgot_password_email(r, l) do
    if should_send_emails?() do
      forgot_password_email(r, l)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def returned_document_or_request_email(thingname, return_comments, _pkg, recp, requestor) do
    new_email(
      to: recp.email,
      from:
        "\"#{requestor.organization} (#{requestor.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject: "#{thingname} Returned for Updates",
      text_body: "Dear #{String.trim(recp.name)},
          The \"#{thingname}\" item sent by #{requestor.name} of #{requestor.organization} has been returned to you for the following updates:
                #{return_comments}

          Please complete as soon as possible and upload at #{email_hostname()}/, after logging in. If you have forgotten your password, you can request a reset there as well. Once completed, the requestor will be notified automatically.

          If you have questions about the documentation request, plase contact #{requestor.email}.

          If you have technical questions about using Boilerplate, please contact support@boilerplate.co

          Have a great day and thank you for using Boilerplate.

          Thanks,
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("returneditem")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      recpName: "#{String.trim(recp.name)}",
      thingName: thingname,
      reqName: requestor.name,
      reqOrg: requestor.organization,
      returnComments: return_comments,
      link: "#{email_hostname()}/login"
    })
  end

  def send_returned_document_or_request_email(tn, rc, p, r, rq) do
    if should_send_emails?() do
      returned_document_or_request_email(tn, rc, p, r, rq)
      |> put_header("Reply-To", rq.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def package_completed_to_recipient(recipient, requestor, recipient_email, requestor_email, pkg) do
    new_email(
      to: recipient_email,
      from:
        "\"#{requestor.organization} (#{requestor.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject:
        "Submitted to #{requestor.name} of #{requestor.organization}: #{pkg.title} via Boilerplate",
      text_body: 
          "Hello #{recipient.name},

          Your #{pkg.title} checklist has been submitted to #{requestor.name} of #{requestor.organization} via Boilerplate. 
          The requester has been notified via email. 
          You’ll receive an email with any adjustments or additional requests after it has been reviewed.

          #{pkg.title} for #{requestor.name} of #{requestor.organization} has been successfully submitted using Boilerplate.  This package includes:

          #{BoilerPlate.Package.construct_list_for_email(pkg)}

          The requestor has been notified and will let you know if there’s anything else needed.
          In the future, you can login at #{email_hostname()}/login at retrieve your submitted documentation.
          Thank you for using Boilerplate.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("packagecompleted_client")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      recipName: recipient.name,
      checklistName: pkg.title,
      reqName: requestor.name,
      reqOrg: requestor.organization,
      reqEmail: requestor_email,
      link: "#{email_hostname()}/login"
    })
  end

  def send_package_completed_to_recipient(rcp, req, rcpe, reqe, contents) do
    if should_send_emails?() do
      Logger.info("Checklist completion: Sending email to recipient ...")

      package_completed_to_recipient(rcp, req, rcpe, reqe, contents)
      |> put_header("Reply-To", reqe)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def countersign_completed(recipient_email, requestor, document, recipient) do
    new_email(
      to: recipient_email,
      from:
        "\"#{requestor.organization} (#{requestor.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject: "#{document.name} Completed",
      text_body: "Hello #{recipient.name},

          ** COMPLETED **

          Thank you, #{recipient.name}!

          #{document.name} was finalized on Boilerplate.

          You can login at #{email_hostname()}/login at retrieve your submitted, final documentation.
          Thank you for using Boilerplate.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("countersign_completed_client")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      recipName: recipient.name,
      documentName: document.name,
      link: "#{email_hostname()}/login"
    })
  end

  def send_countersign_completed(recipient_email, requestor, document, recipient) do
    if should_send_emails?() do
      countersign_completed(recipient_email, requestor, document, recipient)
      |> put_header("Reply-To", requestor.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def package_completed_to_requestor(recipient, requestor, requestor_email, recipient_email, pkg) do
    new_email(
      to: requestor_email,
      from: "notifications@boilerplate.co",
      subject:
        "Submitted for Review: #{recipient.name} of #{recipient.organization} - #{pkg.title}",
      text_body: "Hello #{requestor.name},
          ** READY FOR REVIEW **

          The following package has been submitted and is ready for your review on Boilerplate: #{email_hostname()}/login

          #{recipient.name}
            (of #{recipient.organization})
          Package \"#{pkg.title}\":
            #{BoilerPlate.Package.construct_list_for_email(pkg)}

          Technical help: support@boilerplate.co
          Feedback: feedback@boilerplate.co
          Thank you for using Boilerplate.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("packagecompleted_requestor")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      requestorName: requestor.name,
      recipName: recipient.name,
      recipEmail: recipient_email,
      packageTitle: pkg.title,
      packageList: "#{BoilerPlate.Package.construct_list_for_email(pkg)}",
      link: "#{email_hostname()}/login"
    })
  end

  def send_package_completed_to_requestor(rcp, req, reqe, rcpe, pkg) do
    if should_send_emails?() do
      Logger.info("Checklist completion: Sending email to requestors ...")

      package_completed_to_requestor(rcp, req, reqe, rcpe, pkg)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def new_admin_added(old, new, new_email, link) do
    new_email(
      to: new_email,
      from: "\"#{old.name} via Boilerplate\" <notifications@boilerplate.co>",
      subject: "Boilerplate Activation for #{new.name} by #{old.name}",
      text_body: "Hello #{new.name},
          #{old.name} has just created a Boilerplate account for you. Boilerplate is a secure platform to collect and track documentation.
          Here’s how to get started:
          Click below to set a password:
                #{link}

          Once signed in, the Overview tab will walk you through how to use the platform. You’ll be able to follow the instructions to assign packages from the Recipients tab, review submitted documents, and track progress on the dashboard.

          To prepare and send a request package from scratch:

          Upload or use existing pre-filled or blank forms and templates

          Group them into a package (pause here if you’re not ready to send yet)

          Create a Recipient by entering their email address

          Assign a package for completion

          Your recipient will receive an email with a secure link to the documentation request. Once submitted, you’ll get a confirmation email and the documents will appear on your Review tab, where you can approve each item or return for updates. The Dashboard will update automatically and provide access to the files.

          Don’t hesitate to email success@boilerplate.co for technical support, questions, or feedback.

          Thank you,
          the Boilerplate Team.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("newadmin_added")
    |> Bamboo.MailgunHelper.substitute_variables(%{newname: new.name, link: link})
  end

  def send_new_admin_added(old, new, new_email, link) do
    if should_send_emails?() do
      new_admin_added(old, new, new_email, link)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def password_changed(email, user) do
    new_email(
      to: email,
      from: "notifications@boilerplate.co",
      subject: "Boilerplate Password Changed",
      text_body: "Hello #{user.name},
          Your Boilerplate password has been changed.

          If you don't recognize this activity, please contact your adminstrator and reset your password using the link below. Otherwise no action is required.

          Request new password by using the Forgot Password button here: #{Application.get_env(:boilerplate, :boilerplate_domain)}/

          Thanks for choosing Boilerplate.
          "
    )
    |> email_defaults("password_changed")
    |> Bamboo.MailgunHelper.substitute_variables(%{name: user.name})
  end

  def send_password_changed_email(email, user) do
    if should_send_emails?() do
      password_changed(email, user)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def remind_now_email(_recp, req, pkg, company, recipient_user, remind_now_input) do
    new_email(
      to: recipient_user.email,
      from:
        "\"#{company.name} (#{req.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject: "#{pkg.title} Reminder by #{req.name} for #{company.name}",
      text_body:
        "This email notifies that the #{pkg.title} documentation by #{req.name} for #{company.name} has been requested, including:
          Click the following to open: #{pkg.title}
          Please complete requested documentation at your earliest convenience.
                #{remind_now_input}
          Have a great day and thank you for using Boilerplate.
          Thanks,
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("remindnow_singular")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      recipeintName: req.name,
      companyName: company.name,
      requestedDoc: pkg.title,
      remindNowInput: remind_now_input,
      linkGenerated:
        "#{email_hostname()}/user/#{recipient_user.id}/login/#{login_hash_for(recipient_user)}"
    })
  end

  def send_remind_now_email(recp, req, pkg, company, recipient_user, remind_now_input) do
    if should_send_emails?() do
      remind_now_email(recp, req, pkg, company, recipient_user, remind_now_input)
      |> put_header("Reply-To", req.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def remind_now_list_email(_recp, req, pkg, company, recipient_user, remind_now_input) do
    new_email(
      to: recipient_user.email,
      from:
        "\"#{company.name} (#{req.name}) via Boilerplate [No Reply]\" <notifications@boilerplate.co>",
      subject: "General Reminder by #{req.name} for #{company.name}",
      text_body:
        "This email notifies that the following list of documents by #{req.name} for #{company.name} has been requested, including:
                #{BoilerPlate.Package.construct_list_for_remind_now_email(pkg)}
          Please complete requested documentation at your earliest convenience.
                #{remind_now_input}
          Click here to start!
          Have a great day and thank you for using Boilerplate.
          Thanks,
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("remindnow_list")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      recipeintName: req.name,
      companyName: company.name,
      generatedRequestList: BoilerPlate.Package.construct_list_for_remind_now_email(pkg),
      remindNowInput: remind_now_input,
      linkGenerated:
        "#{email_hostname()}/user/#{recipient_user.id}/login/#{login_hash_for(recipient_user)}"
    })
  end

  def send_remind_now_list_email(
        recp,
        req,
        req_user,
        pkg,
        company,
        recipient_user,
        remind_now_input
      ) do
    if should_send_emails?() do
      remind_now_list_email(recp, req, pkg, company, recipient_user, remind_now_input)
      |> put_header("Reply-To", req_user.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def new_admin_email(target, raw_password) do
    new_email(
      to: target.email,
      from: "notifications@boilerplate.co",
      subject: "Your Boilerplate Admin Account",
      text_body:
        "Welcome to Boilerplate!
          You have been assigned a new administrative account on Boilerplate, the secure platform for managing   digital checklists of documentation and e-signature requests. Here’s how to access your account:
          Site address: https://app.boilerplate.co
          Username: #{target.email}
          Password: #{raw_password}
          GET STARTED HERE: #{email_hostname()}/login
          Please contact us by replying to this email with any questions or feedback.
          Thank you!
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you."
    )
    |> email_defaults("new_admin")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      targetEmail: target.email,
      rawPassword: raw_password,
      link: "#{email_hostname()}/login"
    })
  end

  def send_new_admin_email(target, raw_password) do
    if should_send_emails?() do
      new_admin_email(target, raw_password)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def alternate_admin_email(target, _raw_password) do
    new_email(
      to: target.email,
      from: "notifications@boilerplate.co",
      subject: "Your Boilerplate Admin Account",
      text_body:
        "Welcome to Boilerplate!
          You have been assigned a new administrative account on Boilerplate, the secure platform for managing digital checklists of documentation and e-signature requests. Here’s how to access your account:
          Site address: https://app.boilerplate.co
          Username: #{target.email}
          Your password remains unchanged.
          GET STARTED HERE: #{email_hostname()}/login
          Please contact us by replying to this email with any questions or feedback.
          Thank you!
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you."
    )
    |> email_defaults("new_admin_alt")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      targetEmail: target.email,
      link: "#{email_hostname()}/login"
    })
  end

  def send_alternate_admin_email(target, raw_password) do
    if should_send_emails?() do
      alternate_admin_email(target, raw_password)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def package_completed_to_forward(
        _forward_name,
        forward_email,
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg
      ) do
    new_email(
      to: forward_email,
      from: "boilerplate@boilerplate.co",
      subject:
        "All Finished Forward: #{recipient.name} of #{recipient.organization} - #{pkg.title}",
      text_body: "Hello,
          ** All Done**

          #{requestor.name} (#{requestor_email}) The following checklist has been submitted and reviewed on Boilerplate:

          #{recipient.name} (#{recipient_email}) has completed the #{pkg.title} checklist. The submission is now read for view in Boilerplate.

          Package \"#{pkg.title}\":
            #{BoilerPlate.Package.construct_list_for_email(pkg)}

          Technical help: support@boilerplate.co
          Feedback: feedback@boilerplate.co
          Thank you for using Boilerplate.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("packagecompleted_forward")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      requestorName: requestor.name,
      requestorEmail: requestor_email,
      recipName: recipient.name,
      recipEmail: recipient_email,
      packageTitle: pkg.title,
      packageList: "#{BoilerPlate.Package.construct_list_for_email(pkg)}",
      link: "#{email_hostname()}/login"
    })
  end

  def send_package_completed_to_forward(
        forward_name,
        forward_email,
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg
      ) do
    if should_send_emails?() do
      package_completed_to_forward(
        forward_name,
        forward_email,
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg
      )
      |> put_header("Reply-To", requestor_email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def due_date_expire_email(recipient_user, req, pkg, company, due_date) do
    new_email(
      to: recipient_user.email,
      from: "notifications@boilerplate.co",
      subject:
        "Checklist Overdue: #{recipient_user.name} of #{recipient_user.organization} - #{pkg.title} expired",
      text_body: ""
    )
    |> email_defaults("package_expired_recipient")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      requestorName: req.name,
      requestorEmail: req.email,
      companyName: company.name,
      checklistTitle: pkg.title,
      name: recipient_user.name,
      due_date: due_date,
      link: "#{email_hostname()}/login"
    })
  end

  def document_expiration_email(recipient, requestor, doc, pkg, company, msg) do
    new_email(
      to: recipient.email,
      bcc: requestor.email,
      from: "notifications@boilerplate.co",
      subject: "The document #{doc.document_title} uploaded for checklist #{pkg.title} #{msg}.",
      text_body: ""
    )
    |> email_defaults("document_expiration_notification")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      companyName: company.name,
      checklistTitle: pkg.title,
      recipientname: recipient.name,
      recipientemail: recipient.email,
      docTitle: doc.document_title,
      msg: msg,
      link: "#{email_hostname()}/login"
    })
  end

  def assignment_remind_email(recipient_user, req, pkg, company, due_date) do
    new_email(
      to: recipient_user.email,
      from: "\"#{company.name} (#{req.name}) via Boilerplate\" <notifications@boilerplate.co>",
      subject: "Checklist Reminder by #{req.name} for #{company.name}",
      text_body:
        "This email notifies that the following checklist by #{req.name} for #{company.name} has been requested, including:
                #{pkg.title}
          Please complete requested documentation at your earliest convenience.

          Click here to start!
          Have a great day and thank you for using Boilerplate.
          Thanks,
          The Boilerplate Team
          Like Boilerplate? Find out more at https://boilerplate.co/
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> email_defaults("due_date_remind_list")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      requestorName: req.name,
      requestorEmail: req.email,
      companyName: company.name,
      checklistTitle: pkg.title,
      due_date: due_date,
      link: "#{email_hostname()}/login"
    })
  end

  def weekly_status_email(user, metrics, review_count) do
    new_email(
      to: user.email,
      from: "notifications@boilerplate.co",
      subject: "Boilerplate Weekly Digest",
      text_body: "PLACEHOLDER"
    )
    |> email_defaults("weekly_status")
    |> Bamboo.MailgunHelper.substitute_variables(%{
      user: user.name,
      # Recipients / Contacts
      RecipAndCont: metrics.active_recipients,
      # Checklists Sent
      CheckSent: metrics.checklists_sent,
      # Custom docs sent (RSDs)
      CustDocSent: metrics.rspec_documents_processed,
      # Generic docs sent
      GenDocSent: metrics.generic_documents_processed,
      # Signatures
      Signa: metrics.signature_processed,
      # Files Uploads
      FileUps: metrics.files_uploaded,
      # Data Inputs
      DataInp: metrics.data_inputs,
      # Tasks Completed
      TasksComp: metrics.task_completed,
      # Total Requests Processed
      TotReqProc:
        metrics.data_inputs +
          metrics.rspec_documents_processed +
          metrics.generic_documents_processed +
          metrics.files_uploaded +
          metrics.task_completed +
          metrics.signature_processed,
      TotRev: review_count,
      link: "#{email_hostname()}/login"
    })
  end

  def send_assignment_expire_email_to_recipient(rec_user, req, pkg, company, due_date) do
    if should_send_emails?() do
      due_date_expire_email(rec_user, req, pkg, company, due_date)
      |> put_header("Reply-To", req.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def send_assignment_remind_email_to_recipient(rec_user, req, pkg, company, due_date) do
    if should_send_emails?() do
      assignment_remind_email(rec_user, req, pkg, company, due_date)
      |> put_header("Reply-To", req.email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def send_document_expire_email(document, time_to_expire) do
    if document != [] and should_send_emails?() do
      msg =
        case time_to_expire do
          :one_week ->
            "is expiring next week on #{Timex.format!(document.expiring_date, "{YYYY}-{0M}-{0D}")}"

          :one_month ->
            "is expiring next month on #{Timex.format!(document.expiring_date, "{YYYY}-{0M}-{0D}")}"

          :expired ->
            "has expired"
        end

      document_expiration_email(
        document.recipient,
        document.requestor,
        document,
        document.checklist,
        document.company,
        msg
      )
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def send_weekly_status_email(user, metrics, review_count) do
    if should_send_emails?() do
      weekly_status_email(user, metrics, review_count)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  def document_update_email(
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg,
        doc,
        comment
      ) do
    new_email(
      to: recipient_email,
      from: "boilerplate@boilerplate.co",
      subject:
        "Document Updated: #{recipient.name} of #{recipient.organization}",
      text_body: "Hello,
          #{recipient.name} (#{recipient_email}) The following Document has been updated and send for you to completion:

          #{requestor.name} (#{requestor_email}) has updated the document. The document is now ready for completion.

          Technical help: support@boilerplate.co
          Feedback: feedback@boilerplate.co
          Thank you for using Boilerplate.
          ----
          DISCLAIMER: This email and any attachments or links are strictly confidential. If you are not the intended recipient, or received this message in error, please immediately notify the sender and delete the email from your system. Any unauthorized disclosure is prohibited. Thank you.
          "
    )
    |> Bamboo.MailgunHelper.template("document_update_and_send")
    |> Bamboo.MailgunHelper.template_text(true)
    #
    |> Bamboo.MailgunHelper.substitute_variables(%{
      requestorName: requestor.name,
      requestorEmail: requestor_email,
      recipName: recipient.name,
      recipEmail: recipient_email,
      packageTitle: pkg.title,
      iacDocTitle: doc.name,
      appendNote: comment,
      link: "#{email_hostname()}/login"
    })
  end

  def send_document_updated_to_forward(
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg,
        doc,
        comment
      ) do
    if should_send_emails?() do
      document_update_email(
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        pkg,
        doc,
        comment
      )
      |> put_header("Reply-To", requestor_email)
      |> BoilerPlate.Mailer.deliver_now()
    end
  end

  # LOKCHECK
end
