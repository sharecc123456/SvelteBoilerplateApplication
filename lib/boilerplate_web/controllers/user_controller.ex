alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.User
alias BoilerPlate.Recipient
alias BoilerPlate.Requestor
alias BoilerPlate.Package
alias BoilerPlate.PackageContents
alias BoilerPlate.PackageAssignment
alias BoilerPlate.RawDocument
alias BoilerPlate.Document
alias BoilerPlate.RequestCompletion
alias BoilerPlate.DocumentRequest
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.AdhocLink
alias BoilerPlate.Helpers
import BoilerPlate.AuditLog
import Ecto.Query
import Bitwise
require Logger

defmodule BoilerPlateWeb.UserController do
  use BoilerPlateWeb, :controller

  defp is_first_login_admin?(us_user) do
    is_admin? =
      Repo.aggregate(
        from(r in Requestor, where: r.user_id == ^us_user.id and r.status == 0, select: r),
        :count,
        :id
      ) > 0

    is_admin? and us_user.logins_count == 1
  end

  defp make_redirect(conn) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    is_admin? =
      Repo.aggregate(
        from(r in Requestor, where: r.user_id == ^us_user.id and r.status == 0, select: r),
        :count,
        :id
      ) > 0

    recipient_count =
      Repo.aggregate(
        from(r in Recipient, where: r.user_id == ^us_user.id and r.status == 0, select: r),
        :count,
        :id
      )

    is_first_time_login? = is_first_login_admin?(us_user)

    cond do
      is_first_time_login? ->
        BoilerPlateWeb.StormwindController.resetpassword(conn, %{
          lhash: us_user.password_hash,
          uid: us_user.id,
          email: us_user.email
        })

      is_admin? and recipient_count > 0 ->
        redirect(conn, to: "/midlogin")

      is_admin? ->
        redirect(conn, to: "/n/requestor")

      recipient_count == 1 ->
        redirect(conn, to: "/n/recipient")

      recipient_count > 1 ->
        redirect(conn, to: "/n/recipientc")

      true ->
        conn |> redirect(to: "/recipientDeleted")
    end
  end

  def midlogin(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    is_first_time_login? = is_first_login_admin?(us_user)

    if is_first_time_login? do
      BoilerPlateWeb.StormwindController.resetpassword(conn, %{
        lhash: us_user.password_hash,
        uid: us_user.id,
        email: us_user.email
      })
    else
      BoilerPlateWeb.StormwindController.midlogin(conn, %{email: us_user.email})
    end
  end

  def api_delete_user(requestor, us_user, uid) do
    recipient = Repo.get(Recipient, uid)
    user = Repo.get(User, recipient.user_id)

    company = Repo.get(Company, recipient.company_id)

    if requestor != nil and requestor.company_id == company.id do
      if BoilerPlate.Policy.can_delete?(:recipient, recipient) do
        audit(:recipient_delete, %{
          user: us_user,
          company_id: company.id,
          recipient_name: recipient.name,
          recipient_id: recipient.id,
          recipient_email: user.email,
          user_id: user.id
        })

        cs = Recipient.changeset(recipient, %{status: 1})
        Repo.update!(cs)
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

        :ok
      else
        audit(:recipient_delete_failure, %{
          user: us_user,
          company_id: company.id,
          recipient_name: recipient.name,
          recipient_id: recipient.id,
          recipient_email: user.email,
          user_id: user.id,
          reason: 1
        })

        :assigned_packages
      end
    else
      audit(:recipient_delete_failure, %{
        user: us_user,
        company_id: company.id,
        recipient_name: recipient.name,
        recipient_id: recipient.id,
        recipient_email: user.email,
        user_id: user.id,
        reason: 2
      })

      :forbidden
    end
  end

  defp api_toggle_show_in_dashboard(us_user, uid, bool_value) do
    recipient = Repo.get(Recipient, uid)
    user = Repo.get(User, recipient.user_id)

    company = Repo.get(Company, recipient.company_id)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      audit(:recipient_hide, %{
        user: us_user,
        company_id: company.id,
        recipient_name: recipient.name,
        recipient_id: recipient.id,
        recipient_email: user.email,
        user_id: user.id
      })

      cs = Recipient.changeset(recipient, %{show_in_dashboard: bool_value})
      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

      :ok
    else
      audit(:recipient_delete_failure, %{
        user: us_user,
        company_id: company.id,
        recipient_name: recipient.name,
        recipient_id: recipient.id,
        recipient_email: user.email,
        user_id: user.id,
        reason: 2
      })

      :forbidden
    end
  end

  def api_archive_user(us_user, uid) do
    api_toggle_show_in_dashboard(us_user, uid, false)
  end

  def api_show_user(us_user, uid) do
    api_toggle_show_in_dashboard(us_user, uid, true)
  end

  def api_save_user(us_user, uid, org, name, email, phone_number, start_date \\ nil) do
    recipient = Repo.get(Recipient, uid)
    company = Repo.get(Company, recipient.company_id)
    user = Repo.get(User, recipient.user_id)

    # search for same emails within the company except for the users own email address
    search_existing_email_by_new_email =
      Repo.one(
        from u in User,
          where: u.email == ^email and u.company_id == ^company.id and u.id != ^user.id,
          select: u
      )

    if search_existing_email_by_new_email != nil do
      :forbidden
    else
      if user.email != email do
        # if a user already logged in give back an error
        if user.logins_count < 2 do
          cs = User.changeset(user, %{email: email})
          Repo.update!(cs)
        else
          :forbidden
        end
      end

      if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
        audit(:recipient_edit, %{
          user: us_user,
          company_id: company.id,
          recipient_name: recipient.name,
          recipient_id: recipient.id,
          new_name: name,
          new_org: org,
          recipient_org: recipient.organization,
          user_id: recipient.user_id,
          phone_number: recipient.phone_number,
          new_phone_number: phone_number
        })

        cs =
          Recipient.changeset(recipient, %{
            name: name,
            organization: org,
            phone_number: phone_number,
            start_date: Helpers.get_utc_date(start_date)
          })

        Repo.update!(cs)

        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
        :ok
      else
        audit(:recipient_edit, %{
          user: us_user,
          company_id: company.id,
          recipient_name: recipient.name,
          recipient_id: recipient.id,
          new_name: name,
          new_org: org,
          recipient_org: recipient.organization,
          user_id: recipient.user_id,
          phone_number: recipient.phone_number,
          new_phone_number: phone_number,
          reason: 2
        })

        :forbidden
      end
    end
  end

  # TODO: This needs to be more secure!
  def reset_password(conn, %{"uid" => uid, "hash" => hash}) do
    user = Repo.get(User, uid)

    # Construct the expected password reset hash
    str = "hello_boilerplate_#{user.id}_#{user.password_hash}"
    expected_hash = :crypto.hash(:sha256, str) |> Base.encode16() |> String.downcase()

    if expected_hash == hash do
      render(conn, "password_reset.html", hash: hash, user: user, bad: false)
    else
      Logger.warn(
        "Got invalid pwd reset hash for #{user.name} (id: #{user.id}, email: #{user.email}: expected = #{expected_hash} got = #{hash}"
      )

      text(conn, "Invalid password reset hash")
    end
  end

  def do_reset_password(conn, %{"uid" => uid, "hash" => hash, "password" => pwd}) do
    user = Repo.get(User, uid)
    expected_hash = User.password_reset_hash_for(user)

    if expected_hash == hash do
      Logger.info("Good password reset for #{user.name} (uid: #{user.id}, email: #{user.email})")

      if User.password_ok?(pwd) do
        new_hash = User.hash_password(pwd)

        cs =
          User.changeset(user, %{
            verified: true,
            password_hash: new_hash,
            logins_count: user.logins_count + 1
          })

        Repo.update!(cs)

        BoilerPlate.Email.send_password_changed_email(user.email, user)

        is_admin? =
          Repo.aggregate(
            from(r in Requestor, where: r.user_id == ^user.id and r.status == 0, select: r),
            :count,
            :id
          ) > 0

        conn
        |> BoilerPlate.Guardian.Plug.sign_in(Repo.get(User, user.id), %{blptreq: is_admin?},
          ttl: {720, :minute}
        )
        |> redirect(to: "/")
      else
        render(conn, "password_reset.html", hash: hash, user: user, bad: true)
      end
    else
      Logger.warn(
        "Invalid password reset hash: uid #{uid} hash #{hash} pwd NOTLOGGED expected #{expected_hash}"
      )

      text(conn, "Invalid password reset hash")
    end
  end

  def navigate_reset_password(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    redirect(conn, to: "/password/reset/#{us_user.id}/#{User.password_reset_hash_for(us_user)}")
  end

  def api_get_reset_password_hash(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    expected_hash = User.password_reset_hash_for(us_user)

    json(conn, %{reset_hash: expected_hash, email: us_user.email})
  end

  def api_change_password(conn, %{"pwd" => pwd, "hash" => hash}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    expected_hash = User.password_reset_hash_for(us_user)

    if expected_hash == hash do
      cs = User.changeset(us_user, %{password_hash: pwd, logins_count: us_user.logins_count + 1})
      Repo.update!(cs)

      text(conn, "OK")
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def forgot_password(conn, params) do
    BoilerPlateWeb.StormwindController.forgotpassword(conn, params)
  end

  def do_forgot_password(conn, %{"email" => email}) do
    case api_do_forgot_password(email) do
      :ok -> render(conn, "forgot_password_done.html")
    end
  end

  @spec api_do_forgot_password(String.t()) :: :ok
  def api_do_forgot_password(email) do
    email = String.trim(String.downcase(email))
    user = Repo.one(from u in User, where: u.email == ^email, select: u)

    if user != nil do
      Logger.info("Forgot Password for #{user.name} (id: #{user.id}, email: #{user.email})")

      link =
        "#{Application.get_env(:boilerplate, :boilerplate_domain)}/password/reset/#{user.id}/#{BoilerPlate.User.password_reset_hash_for(user)}"

      BoilerPlate.Email.send_forgot_password_email(user, link)
    else
      Logger.info("Bad Forgot Password Request for email #{email}")
    end

    :ok
  end

  def login(conn, params) do
    # TODO: If logged in, redirect to dashboard
    if BoilerPlate.Guardian.Plug.authenticated?(conn) do
      make_redirect(conn)
    else
      # Otherwise render login screen.
      BoilerPlateWeb.StormwindController.login(conn, params)
    end
  end

  def do_login(conn, %{"email" => username, "password" => raw_password}) do
    conn = conn |> fetch_session()
    attempts = conn |> get_session(:count_attempt_login) || 0
    attempt_expiry = conn |> get_session(:count_attempt_login_expiry)
    current_ts = DateTime.utc_now() |> DateTime.to_unix()
    username = String.trim(String.downcase(username))

    audit(:login_attempt, %{email: username})

    {ok_to_continue, att} =
      cond do
        attempts <= 10 ->
          {true, attempts}

        attempt_expiry != nil and attempt_expiry < current_ts ->
          {true, 0}

        True ->
          {false, attempts}
      end

    attempts = att

    if ok_to_continue do
      conn =
        conn
        |> put_session(:count_attempt_login, attempts + 1)

      Logger.warn("Login attempts in this session: #{attempts}")

      # Hash the password
      password_hash =
        :crypto.hash(:sha256, raw_password)
        |> Base.encode16()
        |> String.downcase()

      user =
        Repo.one(
          from u in User,
            where: u.email == ^username and u.password_hash == ^password_hash,
            select: u
        )

      if user == nil do
        audit(:login_failure, %{email: username, reason: 1})

        if User.exists?(username) do
          conn
          |> put_session(
            :bp_problem_text_login,
            "You’ve entered an incorrect password. Please check that you have entered it correctly. If that doesn’t resolve your issue, use the Forgot Password link below."
          )
          |> redirect(to: "/login")
        else
          conn
          |> put_session(:bp_problem_text_login, "This email does not seem to exist.")
          |> redirect(to: "/login")
        end
      else
        conn =
          conn
          |> fetch_session()
          |> delete_session(:count_attempt_login)
          |> delete_session(:count_attempt_login_expiry)

        audit_identify(user)
        audit(:login_success, %{user: user})

        claims =
          if BoilerPlate.TwoFactorComputer.is_this_remembered_for?(conn, user) do
            %{two_factor_approved: true}
          else
            %{}
          end

        conn
        |> BoilerPlate.Guardian.Plug.sign_in(user, claims, ttl: {720, :minute})
        |> make_redirect()
      end
    else
      BoilerPlate.AuditLog.audit(:login_banned)

      conn
      |> put_session(
        :bp_problem_text_login,
        "ACCESS TEMPORARILY SUSPENDED: For your security, access to your account has been temporarily suspended due to too many failed login attempts. Please check that you are using the correct email address and try again in about 5 minutes."
      )
      |> put_session(
        :count_attempt_login_expiry,
        300 + (DateTime.utc_now() |> DateTime.to_unix())
      )
      |> redirect(to: "/login")
    end
  end

  def logout(conn, _params) do
    user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if user != nil do
      BoilerPlate.AuditLog.audit(:logout, user)
    else
      BoilerPlate.AuditLog.audit(:logout_nouser)
    end

    conn
    |> fetch_session()
    |> put_session(:recipient_company_id, nil)
    |> BoilerPlate.Guardian.Plug.sign_out()
    |> redirect(to: "/")
  end

  def show_user(conn, _params) do
    redirect(conn, to: "/n/recipient")
  end

  def login_recipient(conn, %{"uid" => uid, "loginhash" => lhash}) do
    user = Repo.get(User, uid)

    if lhash == user.password_hash and (user.flags &&& 2) == 0 do
      Logger.info("OK login_recipient link for uid #{uid}")

      Repo.update!(User.changeset(user, %{verified: true}))

      user = Repo.get(User, user.id)

      BoilerPlateWeb.StormwindController.resetpassword(conn, %{
        lhash: user.password_hash,
        uid: user.id,
        email: user.email
      })
    else
      Logger.warn("Bad login_recipient link for uid #{uid} loginhash #{lhash}")
      # render conn, "bad_login_recipient.html"
      redirect(conn, to: "/")
    end
  end

  def do_login_recipient(conn, %{"uid" => uid, "hash" => lhashm, "password" => pwd}) do
    user = Repo.get(User, uid)

    if lhashm == user.password_hash and (user.flags &&& 2) == 0 do
      hashed_password = User.hash_password(pwd)
      cs = User.changeset(user, %{password_hash: hashed_password, flags: user.flags ||| 2})

      Repo.update!(cs)

      user = Repo.get(User, uid)

      conn
      |> BoilerPlate.Guardian.Plug.sign_in(user, %{}, ttl: {720, :minute})
      |> redirect(to: "/user")
    else
      text(conn, "invalid hash or internal state")
    end
  end

  def send_package_completed_email(contents, requestor_id, recipient) do
    requestor = Repo.get(Requestor, requestor_id)
    requestor_user = Repo.get(User, requestor.user_id)
    recipient_email = Repo.get(User, recipient.user_id).email
    requestor_email = requestor_user.email
    notify_admins? = requestor.notify_admins

    company_admins =
      if notify_admins? do
        company = Repo.get(Company, requestor.company_id)
        User.all_active_users_for(company)
      else
        [requestor_user]
      end

    BoilerPlate.Email.send_package_completed_to_recipient(
      recipient,
      requestor,
      recipient_email,
      requestor_email,
      contents
    )

    company_admins
    |> Enum.each(fn admin ->
      BoilerPlate.Email.send_package_completed_to_requestor(
        recipient,
        admin,
        admin.email,
        recipient_email,
        contents
      )
    end)

    :ok
  end

  def api_upload_user_document(us_user, uid, assignid, rawdocid, real_file, file) do
    rawdocument = Repo.get(RawDocument, rawdocid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    # if recipient.user_id == us_user.id do
    {status, final_path} =
      if real_file do
        template_fn = UUID.uuid4() <> Path.extname(file.filename)

        Document.store(%{
          filename: template_fn,
          path: file.path
        })
      else
        {:ok, file}
      end

    if status == :ok do
      # Supersede all previous uploads in this class
      previous_ds =
        Repo.all(
          from d in Document,
            where: d.raw_document_id == ^rawdocument.id and d.assignment_id == ^assign.id,
            select: d
        )

      is_a_replace? = previous_ds |> Enum.filter(&(&1.status == 1)) |> length() != 0

      for doc <- previous_ds do
        Repo.update!(Document.changeset(doc, %{status: 4}))
      end

      template = %Document{
        raw_document_id: rawdocument.id,
        recipient_id: recipient.id,
        status:
          if real_file do
            1
          else
            2
          end,
        flags: 0,
        filename: final_path,
        assignment_id: assign.id,
        company_id: recipient.company_id
      }

      md = Repo.insert!(template)

      audit(:recipient_document_upload, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        final_path: final_path,
        raw_id: rawdocument.id,
        document_id: md.id
      })

      package = Repo.get(Package, assign.package_id)

      if package != nil do
        if Package.check_if_completed_by(assign, recipient) and
             not is_a_replace? do
          send_package_completed_email(contents, assign.requestor_id, recipient)
        end
      end

      :ok
    else
      audit(:recipient_document_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        raw_id: rawdocument.id,
        reason: 1
      })

      :bad_file
    end

    # else
    # audit(:recipient_document_upload_failure, %{
    # user: us_user,
    # company_id: recipient.company_id,
    # assignment_id: assign.id,
    # contents_id: assign.contents_id,
    # recipient_id: recipient.id,
    # raw_id: rawdocument.id,
    # reason: 2
    # })

    # :forbidden
    # end
  end

  def api_fillin_user_request(us_user, uid, assignid, requestid, upl) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_fillin_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        fillin_string: upl,
        reason: 2
      })

      :forbidden
    else
      # Supersede all previous uploads in this class
      previous_rcs =
        Repo.all(
          from d in RequestCompletion,
            where: d.requestid == ^request.id and d.assignment_id == ^assign.id,
            select: d
        )

      is_a_replace? = previous_rcs |> Enum.filter(&(&1.status == 1)) |> length() != 0

      for req <- previous_rcs do
        Repo.update!(RequestCompletion.changeset(req, %{status: 4}))
      end

      template = %RequestCompletion{
        recipientid: recipient.id,
        file_name: upl,
        status: 1,
        flags: 0,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        requestid: request.id
      }

      md = Repo.insert!(template)

      audit(:recipient_request_fillin, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        request_completion_id: md.id,
        fillin_string: upl
      })

      package = Repo.get(Package, assign.package_id)

      if package != nil do
        if Package.check_if_completed_by(assign, recipient) and
             not is_a_replace? do
          send_package_completed_email(contents, assign.requestor_id, recipient)
        end
      end

      :ok
    end
  end

  def has_confirmation_file_uploads?(requestid) do
    Repo.aggregate(
      from(req_com in RequestCompletion,
        where: req_com.file_request_reference == ^requestid and req_com.status == 0,
        select: req_com
      ),
      :count,
      :id
    ) > 0
  end

  def api_mark_done_taskrequest(us_user, uid, assignid, requestid) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_task_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      :forbidden
    else
      # Supersede all previous uploads in this class
      previous_rcs =
        Repo.all(
          from d in RequestCompletion,
            where: d.requestid == ^request.id and d.assignment_id == ^assign.id,
            select: d
        )

      is_a_replace? = previous_rcs |> Enum.filter(&(&1.status == 1)) |> length() != 0

      for req <- previous_rcs do
        Repo.update!(RequestCompletion.changeset(req, %{status: 4}))
      end

      template = %RequestCompletion{
        recipientid: recipient.id,
        file_name: "",
        status: 1,
        flags: 0,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        requestid: request.id
      }

      md = Repo.insert!(template)

      if has_confirmation_file_uploads?(requestid) do
        task_confirmation_upload_doc =
          Repo.get_by(RequestCompletion, %{file_request_reference: request.id, status: 0})

        Repo.update!(RequestCompletion.changeset(task_confirmation_upload_doc, %{status: 1}))

        description_ch =
          DocumentRequest.get_changeset_task_description(task_confirmation_upload_doc, request.id)

        Repo.update!(description_ch)
      end

      audit(:recipient_request_task, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        request_completion_id: md.id
      })

      package = Repo.get(Package, assign.package_id)

      if package != nil do
        if Package.check_if_completed_by(assign, recipient) and
             not is_a_replace? do
          send_package_completed_email(contents, assign.requestor_id, recipient)
        end
      end

      :ok
    end
  end

  def api_upload_user_request(us_user, uid, assignid, requestid, file, reset) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      :forbidden
    else
      template_fn = UUID.uuid4() <> Path.extname(file.filename)

      {status, final_path} =
        RequestCompletion.store(%{
          filename: template_fn,
          path: file.path
        })

      if status == :ok do
        # Supersede all previous uploads in this class
        previous_rcs =
          Repo.all(
            from d in RequestCompletion,
              where:
                d.requestid == ^request.id and d.assignment_id == ^assign.id and d.status != 0,
              select: d
          )

        is_a_replace? = previous_rcs |> Enum.filter(&(&1.status == 1)) |> length() != 0

        if reset == true do
          for req <- previous_rcs do
            Repo.update!(RequestCompletion.changeset(req, %{status: 4}))
          end
        end

        template = %RequestCompletion{
          recipientid: recipient.id,
          file_name: final_path,
          status: 1,
          flags: 0,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          requestid: request.id
        }

        md = Repo.insert!(template)

        audit(:recipient_request_upload, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          final_path: final_path,
          request_id: request.id,
          request_completion_id: md.id
        })

        package = Repo.get(Package, assign.package_id)

        if package != nil do
          if Package.check_if_completed_by(assign, recipient) and
               not is_a_replace? do
            send_package_completed_email(contents, assign.requestor_id, recipient)
          end
        end

        :ok
      else
        audit(:recipient_request_upload_failure, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          request_id: request.id,
          reason: 1
        })

        :wrong_filetype
      end
    end
  end

  def api_upload_additional_requests(us_user, uid, assignid, requestid, req_name, file) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      :forbidden
    else
      Repo.update!(DocumentRequest.changeset(request, %{title: req_name, flags: 2}))
      template_fn = UUID.uuid4() <> Path.extname(file.filename)

      {status, final_path} =
        RequestCompletion.store(%{
          filename: template_fn,
          path: file.path
        })

      if status == :ok do
        template = %RequestCompletion{
          recipientid: recipient.id,
          file_name: final_path,
          status: 1,
          # manually submitted extra files recipient
          flags: 2,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          requestid: request.id
        }

        md = Repo.insert!(template)

        # create new request as a extra for additional file uploads
        req = %DocumentRequest{
          packageid: 0,
          title: request.title,
          attributes: request.attributes,
          status: 0,
          flags: 4
        }

        n = Repo.insert!(req)

        new_requests = contents.requests ++ [n.id]

        Repo.update(PackageContents.changeset(contents, %{requests: new_requests}))

        audit(:recipient_request_upload, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          final_path: final_path,
          request_id: request.id,
          request_completion_id: md.id
        })

        {:ok, n.id}
      else
        audit(:recipient_request_upload_failure, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          request_id: request.id,
          reason: 1
        })

        {:wrong_filetype, nil}
      end
    end
  end

  def api_save_user_request(us_user, uid, assignid, requestid, file, _reset) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      {:forbidden, nil}
    else
      template_fn = UUID.uuid4() <> Path.extname(file.filename)

      # allow preview files which can be viwed in BLPT
      request_status =
        if BoilerPlate.DocumentRequest.validateFileTypeViewable?(template_fn) do
          # In progress -> preview
          0
        else
          1
        end

      {status, final_path} =
        RequestCompletion.store(%{
          filename: template_fn,
          path: file.path
        })

      if status == :ok do
        previous_rcs =
          Repo.one(
            from d in RequestCompletion,
              where:
                d.requestid == ^request.id and d.assignment_id == ^assign.id and d.status == 0,
              select: d
          )

        # Looks for previous missing status but later uploaded requests
        missing_previous_rcs =
          Repo.one(
            from d in RequestCompletion,
              where:
                d.requestid == ^request.id and d.assignment_id == ^assign.id and d.status == 5,
              select: d
          )

        is_a_replace? = previous_rcs != nil
        is_missing_status? = missing_previous_rcs != nil

        md =
          if is_a_replace? do
            Repo.update!(RequestCompletion.changeset(previous_rcs, %{file_name: final_path}))
          else
            if is_missing_status? do
              Repo.update!(
                RequestCompletion.changeset(missing_previous_rcs, %{
                  file_name: final_path,
                  status: request_status,
                  is_missing: false,
                  missing_reason: ""
                })
              )
            else
              template = %RequestCompletion{
                recipientid: recipient.id,
                file_name: final_path,
                status: request_status,
                flags: 0,
                company_id: recipient.company_id,
                assignment_id: assign.id,
                requestid: request.id
              }

              Repo.insert!(template)
            end
          end

        audit(:recipient_request_upload, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          final_path: final_path,
          request_id: request.id,
          request_completion_id: md.id
        })

        {:ok, md.id, request_status}
      else
        audit(:recipient_request_upload_failure, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          request_id: request.id,
          reason: 1
        })

        {:wrong_filetype, nil}
      end
    end
  end

  def api_submit_uploaded_user_request(us_user, uid, completion_id, requestid) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    uploaded_req = Repo.get(RequestCompletion, completion_id)
    assign = Repo.get(PackageAssignment, uploaded_req.assignment_id)
    contents = Repo.get(PackageContents, assign.contents_id)

    if recipient.user_id != us_user.id do
      audit(:recipient_request_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      :forbidden
    else
      Repo.update!(RequestCompletion.changeset(uploaded_req, %{status: 1}))

      if uploaded_req.file_request_reference != nil do
        description_ch =
          DocumentRequest.get_changeset_task_description(
            uploaded_req,
            uploaded_req.file_request_reference
          )

        Repo.update!(description_ch)
      end

      audit(:recipient_request_upload, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        final_path: uploaded_req.file_name,
        request_id: request.id,
        request_completion_id: completion_id
      })

      package = Repo.get(Package, assign.package_id)

      if package != nil && Package.check_if_completed_by(assign, recipient) do
        send_package_completed_email(contents, assign.requestor_id, recipient)
      end

      :ok
    end
  end

  def api_manual_upload(
        requestor,
        us_user,
        rawdocid,
        assignid,
        uid,
        upl,
        :document
      ) do
    rawdocument = Repo.get(RawDocument, rawdocid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if requestor != nil and requestor.company_id == recipient.company_id do
      template_fn = UUID.uuid4() <> Path.extname(upl.filename)

      {status, final_path} =
        Document.store(%{
          filename: template_fn,
          path: upl.path
        })

      if status == :ok do
        # Supersede all previous uploads in this class
        previous_ds =
          Repo.all(
            from d in Document,
              where: d.raw_document_id == ^rawdocument.id and d.assignment_id == ^assign.id,
              select: d
          )

        is_a_replace? = previous_ds |> Enum.filter(&(&1.status == 1)) |> length() != 0

        for doc <- previous_ds do
          Repo.update!(Document.changeset(doc, %{status: 4}))
        end

        Logger.info(
          "New document manually uploaded by #{us_user.name} (requestor id: #{requestor.id}, email: #{us_user.email}) for #{recipient.name}, to assignid #{assignid}, rawdocid #{rawdocid} \"#{rawdocument.name}\""
        )

        template = %Document{
          raw_document_id: rawdocument.id,
          recipient_id: recipient.id,
          status: 2,
          flags: 4,
          filename: final_path,
          assignment_id: assign.id,
          company_id: recipient.company_id
        }

        Repo.insert!(template)

        cs = PackageAssignment.changeset(assign, %{open_status: 1})
        Repo.update!(cs)

        package = Repo.get(Package, assign.package_id)

        if package != nil do
          if Package.check_if_completed_by(assign, recipient) and
               not is_a_replace? do
            send_package_completed_email(contents, assign.requestor_id, recipient)
          end
        end

        :ok
      else
        :bad_file
      end
    else
      Logger.warn(
        "[uid #{us_user.id}] Tried manually uploading document, but forbidden. uid #{uid} assignid #{assignid} docid #{rawdocid}"
      )

      :forbidden
    end
  end

  def api_manual_upload(requestor, us_user, uid, assignid, requestid, upl, :request) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if requestor == nil or requestor.company_id != recipient.company_id do
      Logger.warn(
        "[uid #{us_user.id}] Tried manually uploading request, but forbidden. uid #{uid} assignid #{assignid} reqid #{requestid}"
      )

      :forbidden
    else
      template_fn = UUID.uuid4() <> Path.extname(upl.filename)

      {status, final_path} =
        RequestCompletion.store(%{
          filename: template_fn,
          path: upl.path
        })

      if status == :ok do
        # Supersede all previous uploads in this class
        previous_rcs =
          Repo.all(
            from d in RequestCompletion,
              where: d.requestid == ^request.id and d.assignment_id == ^assign.id,
              select: d
          )

        is_a_replace? = previous_rcs |> Enum.filter(&(&1.status == 1)) |> length() != 0

        for req <- previous_rcs do
          Repo.update!(RequestCompletion.changeset(req, %{status: 4}))
        end

        Logger.info(
          "New request manually uploaded by #{requestor.name} (requestor id: #{requestor.id}, email: #{us_user.email}) for #{recipient.name}, to assignid #{assignid}, reqid #{requestid} \"#{request.title}\""
        )

        template = %RequestCompletion{
          recipientid: recipient.id,
          file_name: final_path,
          status: 2,
          flags: 4,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          requestid: request.id
        }

        Repo.insert!(template)

        cs = PackageAssignment.changeset(assign, %{open_status: 1})
        Repo.update!(cs)

        package = Repo.get(Package, assign.package_id)

        if package != nil do
          if Package.check_if_completed_by(assign, recipient) and
               not is_a_replace? do
            send_package_completed_email(contents, assign.requestor_id, recipient)
          end
        end

        :ok
      else
        :bad_file
      end
    end
  end

  def check_package_completion_and_send_mail(pkgId, assignment, recipient) do
    package = Repo.get(Package, pkgId)

    if package != nil and Package.check_if_completed_by(assignment, recipient) do
      contents = Repo.get(PackageContents, assignment.contents_id)

      if send_package_completed_email(contents, assignment.requestor_id, recipient) == :ok do
        :email_send
      else
        :error
      end
    else
      :package_not_completed
    end
  end

  def upload_recipient_request(us_user, uid, assignid, requestid, file) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, uid)
    assign = Repo.get(PackageAssignment, assignid)
    contents = Repo.get(PackageContents, assign.contents_id)

    if assign == nil or contents == nil or recipient.user_id != us_user.id do
      audit(:recipient_request_upload_failure, %{
        user: us_user,
        company_id: recipient.company_id,
        assignment_id: assign.id,
        contents_id: assign.contents_id,
        recipient_id: recipient.id,
        request_id: request.id,
        reason: 2
      })

      :forbidden
    else
      template_fn = UUID.uuid4() <> Path.extname(file.filename)

      {status, final_path} =
        RequestCompletion.store(%{
          filename: template_fn,
          path: file.path
        })

      if status == :ok do
        template = %RequestCompletion{
          recipientid: recipient.id,
          file_name: final_path,
          status: 1,
          flags: 0,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          requestid: request.id
        }

        md = Repo.insert!(template)

        audit(:recipient_request_upload, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          final_path: final_path,
          request_id: request.id,
          request_completion_id: md.id
        })

        :ok
      else
        audit(:recipient_request_upload_failure, %{
          user: us_user,
          company_id: recipient.company_id,
          assignment_id: assign.id,
          contents_id: assign.contents_id,
          recipient_id: recipient.id,
          request_id: request.id,
          reason: 1
        })

        :wrong_filetype
      end
    end
  end

  def create_request_and_upload_docs(us_user, rid, aid, requestid, file_to_upload) do
    request = Repo.get(DocumentRequest, requestid)
    recipient = Repo.get(Recipient, rid)
    assign = Repo.get(PackageAssignment, aid)
    contents = Repo.get(PackageContents, assign.contents_id)

    req = %DocumentRequest{
      packageid: 0,
      title: "#{request.title} #{file_to_upload.filename}",
      attributes: request.attributes,
      status: request.status,
      flags: 8,
      enable_expiration_tracking: request.enable_expiration_tracking,
      file_retention_period: request.file_retention_period
    }

    n = Repo.insert!(req)

    new_req = contents.requests ++ [n.id]
    cs = PackageContents.changeset(contents, %{requests: new_req})
    Repo.update!(cs)

    case upload_recipient_request(us_user, recipient.id, aid, n.id, file_to_upload) do
      :forbidden ->
        :forbidden

      :ok ->
        :ok

      :wrong_filetype ->
        :wrong_filetype
    end
  end

  def show_adhoc_link(:package, conn, adhoc) do
    BoilerPlateWeb.StormwindController.adhoc_package(conn, adhoc)
  end

  def do_adhoc_register(:package, conn, adhoc, name, email, pwd) do
    package = Repo.get(Package, adhoc.type_id)
    pkg_company = Repo.get(Company, package.company_id)
    valid? = adhoc.status == 0

    if valid? do
      # Check if this emails has a Boilerplate account
      if User.exists?(email) do
        user = Repo.one(from u in User, where: u.email == ^email, select: u)
        # If they have an account, add the assignment and forward them to their login screen.
        recipient =
          Repo.one(
            from r in Recipient,
              where: r.company_id == ^pkg_company.id and r.status == 0 and r.user_id == ^user.id,
              select: r
          )

        if recipient != nil do
          # Check if the recipient has any related assignments
          assignment =
            Repo.one(
              from pa in PackageAssignment,
                where:
                  pa.package_id == ^package.id and pa.status == 0 and
                    pa.recipient_id == ^recipient.id,
                select: pa
            )

          if assignment != nil do
            # Already assigned, redirect user to login.
            # TODO: display some guidance
            redirect(conn, to: "/login")
          else
            # The recipient and user exist - assign the package and forward them to login.
            pa = %PackageAssignment{
              company_id: pkg_company.id,
              flags: 0,
              status: 0,
              package_id: package.id,
              contents_id: PackageContents.from_package(recipient, package).id,
              recipient_id: recipient.id,
              requestor_id: adhoc.requestor_id,
              enforce_due_date: false,
              append_note: "",
              docs_downloaded: []
            }

            Repo.insert!(pa)

            # Assignment complete - send them to login
            # TODO: display some guidance
            redirect(conn, to: "/login")
          end
        else
          # The user exists, but there is no recipient record yet.
          ra =
            Repo.insert!(%Recipient{
              company_id: pkg_company.id,
              name: name,
              organization: pkg_company.name,
              status: 0,
              terms_accepted: false,
              user_id: user.id
            })

          # Now there is a recipient for the user, add the assignment to it.
          pa = %PackageAssignment{
            company_id: pkg_company.id,
            flags: 0,
            status: 0,
            package_id: package.id,
            contents_id: PackageContents.from_package(ra, package).id,
            recipient_id: ra.id,
            requestor_id: adhoc.requestor_id,
            enforce_due_date: false,
            append_note: "",
            docs_downloaded: []
          }

          Repo.insert!(pa)

          # All done.
          # TODO: display some guidance
          redirect(conn, to: "/login")
        end
      else
        # The user does not exist yet.
        if pwd != nil and User.password_ok?(pwd) do
          new = %User{
            name: name,
            email: String.downcase(email),
            company_id: pkg_company.id,
            organization: pkg_company.name,
            admin_of: nil,
            access_code: "null",
            username: "null",
            verified: true,
            verification_code: User.new_password(16),
            flags: 0,
            password_hash: User.hash_password(pwd),
            current_document_index: 0
          }

          n = Repo.insert!(new)

          ra =
            Repo.insert!(%Recipient{
              company_id: pkg_company.id,
              name: name,
              organization: pkg_company.name,
              status: 0,
              terms_accepted: false,
              user_id: n.id
            })

          pa = %PackageAssignment{
            company_id: pkg_company.id,
            flags: 0,
            status: 0,
            package_id: package.id,
            contents_id: PackageContents.from_package(ra, package).id,
            recipient_id: ra.id,
            requestor_id: adhoc.requestor_id,
            enforce_due_date: false,
            append_note: "",
            docs_downloaded: []
          }

          Repo.insert!(pa)

          conn
          |> BoilerPlate.Guardian.Plug.sign_in(n, %{}, ttl: {720, :minute})
          |> redirect(to: "/user")
        else
          conn
          |> render("adhoc_package_password.html",
            name: name,
            package: package,
            company: pkg_company,
            email: email,
            bad: pwd != nil and not User.password_ok?(pwd),
            adhoc: adhoc
          )
        end
      end
    else
      Logger.warn(
        "[Guest user] Tried to register adhoc via adhoc #{adhoc.id} that is not longer valid"
      )
    end
  end

  def handle_adhoc_link(conn, %{"adhoc_str" => adhoc_str}) do
    adhoc = Repo.one(from a in AdhocLink, where: a.adhoc_string == ^adhoc_str, select: a)
    valid? = adhoc != nil and adhoc.status == 0

    if valid? do
      conn = conn |> BoilerPlate.Guardian.Plug.sign_out()
      type_atom = AdhocLink.type_to_atom(adhoc.type)

      case type_atom do
        :package ->
          show_adhoc_link(:package, conn, adhoc)

        :unknown ->
          Logger.warn(
            "[Guest user] Tried to access adhoc link #{adhoc.id} that is of unknown type"
          )

          conn |> put_status(403) |> text("Forbidden")
      end
    else
      if adhoc != nil do
        Logger.warn(
          "[Guest user] Tried to access adhoc link #{adhoc.id} that is not longer valid"
        )
      end

      BoilerPlateWeb.StormwindController.bad_adhoc(conn, %{})
    end
  end

  def handle_adhoc_register(conn, %{
        "adhoc_str" => adhoc_str,
        "user_name" => name,
        "email" => email
      }) do
    adhoc = Repo.one(from a in AdhocLink, where: a.adhoc_string == ^adhoc_str, select: a)
    valid? = adhoc.status == 0
    email = String.trim(String.downcase(email))

    if valid? do
      type_atom = AdhocLink.type_to_atom(adhoc.type)

      case type_atom do
        :package ->
          do_adhoc_register(:package, conn, adhoc, name, email, nil)

        :unknown ->
          Logger.warn(
            "[Guest user] Tried to access adhoc register #{adhoc.id} that is of unknown type"
          )

          conn |> put_status(403) |> text("Forbidden")
      end
    else
      Logger.warn(
        "[Guest user] Tried to access adhoc register#{adhoc.id} that is not longer valid"
      )
    end
  end

  def verify_email(conn, %{"verification_code" => verification_code}) do
    user = Repo.get_by(User, verification_code: verification_code)

    if user == nil do
      text(conn, "Invalid verification code")
    else
      Repo.update!(User.changeset(user, %{verified: true}))

      audit(:verify_email, %{user: user})

      conn
      |> BoilerPlate.Guardian.Plug.sign_out()
      |> BoilerPlate.Guardian.Plug.sign_in(user, %{}, ttl: {720, :minute})
      # |> fetch_session()
      # |> put_session(:bp_problem_text, "Your email has been verified and you have been logged in!")
      |> redirect(to: "/")
    end
  end

  def accept_termsofservice(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    cs = User.changeset(us_user, %{terms_accepted: true})
    Repo.update!(cs)

    audit(:accept_tos, %{user: us_user})

    redirect(conn, to: "/")
  end

  def assignment_completion_email_notification(conn, %{
        "assignment_id" => assignments_id,
        "emailAddress" => forward_email,
        "forward_name" => forward_name
      }) do
    assignments = Repo.get(PackageAssignment, assignments_id)

    requestor = Repo.get(Requestor, assignments.requestor_id)
    recipient = Repo.get(Recipient, assignments.recipient_id)

    requestor_email = Repo.get(User, requestor.user_id).email
    recipient_email = Repo.get(User, recipient.user_id).email

    package = Repo.get(PackageContents, assignments.contents_id)

    # forward_name, forward_email, requestor, requestor_email, recipient, recipient_email, pkg
    if package != nil do
      BoilerPlate.Email.send_package_completed_to_forward(
        forward_name,
        forward_email,
        requestor,
        requestor_email,
        recipient,
        recipient_email,
        package
      )

      json(conn, %{status: :ok})
    else
      conn |> put_status(400) |> json(%{error: :invalid_assignment})
    end
  end

  def requestor_document_update_email_notification(conn, %{
        "iacDocId" => iac_doc_id,
        "comment" => comment
      }
      ) do
    requestor = get_current_requestor(conn)
    with iac_document <- Repo.get!(IACDocument, iac_doc_id) do
      master_doc = Repo.get(IACMasterForm, iac_document.master_form_id)
      recipient = Repo.get(Recipient, iac_document.recipient_id)

      requestor_email = Repo.get(User, requestor.user_id).email
      recipient_email = Repo.get(User, recipient.user_id).email

      package_contents = Repo.get(PackageContents, iac_document.contents_id)

      if package_contents != nil do
        BoilerPlate.Email.send_document_updated_to_forward(
          requestor,
          requestor_email,
          recipient,
          recipient_email,
          package_contents,
          master_doc,
          comment
        )

        json(conn, %{status: :ok})
      else
        conn |> put_status(400) |> json(%{error: :invalid_assignment})
      end
    else
      nil ->
        conn |> put_status(404) |> json(%{error: :invalid_document_id})
    end
  end

  def add_text_signature(conn, %{"text_signature" => text_signature}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    Logger.info("Text signature set to #{text_signature} for userid: #{us_user.id}")

    cs = User.changeset(us_user, %{text_signature: text_signature})
    Repo.update!(cs)
    conn |> json(%{status: :ok})
  end

  def get_text_signature(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    Logger.info("Text signature loaded: #{us_user.text_signature} for userid: #{us_user.id}")

    if us_user.text_signature !== "" do
      json(conn, us_user.text_signature)
    else
      json(conn, [])
    end
  end

  def toggle_admin_notifications(conn, %{"id" => requestor_id, "flag" => notify_admin}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)

    if requestor != nil and us_user.id == requestor.user_id and
         requestor.user_id == String.to_integer(requestor_id) do
      cs = Requestor.changeset(requestor, %{notify_admins: notify_admin})
      Repo.update!(cs)
      text(conn, :ok)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def toggle_weekly_digest(conn, %{"id" => requestor_id, "flag" => flag}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)

    if requestor != nil and us_user.id == requestor.user_id and
         requestor.user_id == String.to_integer(requestor_id) do
      cs = Requestor.changeset(requestor, %{weekly_digest: flag})
      Repo.update!(cs)
      text(conn, :ok)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  @login_hash_v2_secret "HUsdmmbkm306vO+COjZAawC3FA2wWFLCom7EtKk2cuM0T5taDStZscOENUyF2kNp"
  def login_hash_v2_for(user) do
    :crypto.mac(:hmac, :sha256, @login_hash_v2_secret, user.password_hash)
    |> Base.encode16()
    |> String.downcase()
  end

  def login_recipient_v2(conn, %{"uid" => uid, "loginhash" => actual_value}) do
    user = Repo.get(User, uid)

    if user != nil do
      expected_value = login_hash_v2_for(user)

      if expected_value != actual_value do
        text(conn, "Bad login hash for v2LR")
      else
        Repo.update!(User.changeset(user, %{verified: true}))

        BoilerPlateWeb.StormwindController.resetpassword(conn, %{
          lhash: user.password_hash,
          uid: user.id,
          email: user.email
        })
      end
    else
      text(conn, "Invalid User for v2LR")
    end
  end

  def retrieve_link(conn, %{"uid" => user_id}) do
    IO.inspect("retrieve_link called")
    rec_user = Repo.get(User, user_id)

    link =
      "#{Application.get_env(:boilerplate, :boilerplate_domain)}/v2/user/#{rec_user.id}/login/#{login_hash_v2_for(rec_user)}/"

    IO.inspect(link, label: "retrive_link/label")

    json(conn, %{link: link})
  end
end
