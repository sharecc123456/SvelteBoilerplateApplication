import Ecto.Query
alias BoilerPlate.AuditLog
alias BoilerPlate.EsignAuditItem
alias BoilerPlate.User
alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.Cabinet
alias BoilerPlate.Document
alias BoilerPlate.PackageAssignment
alias BoilerPlate.PackageContents
alias BoilerPlate.Recipient
alias BoilerPlate.Requestor
alias BoilerPlate.IACAppendix
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACAssignedForm
alias BoilerPlate.IACField
alias BoilerPlate.IACSignature
alias BoilerPlate.IACSignatureHash
alias BoilerPlate.IACSESExportable
alias BoilerPlate.IACLabel
alias BoilerPlate.Package
alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized

require Logger

defmodule BoilerPlateWeb.IACController do
  alias BoilerPlate.AccessPolicy
  use BoilerPlateWeb, :controller

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  defp gen_iac_sighash_for(iacsig) do
    :crypto.hash(:sha256, "sig-#{iacsig.id}-#{iacsig.updated_at}")
    |> Base.encode16()
    |> String.downcase()
    |> String.slice(0..12)
  end

  ##########################
  # Actual controller code #
  ##########################

  defp location_type_if(true), do: :textract_topleft
  defp location_type_if(false), do: :not_written

  def api_add_field(_us_user, tid, type) do
    iac_doc = Repo.get(IACDocument, tid)
    master_form = Repo.get(IACMasterForm, iac_doc.master_form_id)
    is_master_field? = true
    needs_location? = type in ["text", "signature", "selection", "selection", "table"]
    allowed_types = ["line", "horizontal_line", "text", "signature", "selection", "table"]

    # TODO: audit, access policy

    if not is_master_field? or type not in allowed_types do
      :invalid_state
    else
      # Create the new IACField
      new_field = %IACField{
        parent_id: master_form.id,
        parent_type: 1,
        name: "New Field",
        location_type: IACField.atom_to_location_type(location_type_if(needs_location?)),
        location_value_1: 0.0,
        location_value_2: 0.0,
        location_value_3: 0.0,
        location_value_4: 0.0,
        location_value_5: 0.0,
        location_value_6: 0.0,
        field_type: IACField.type_string_to_type_int(type),
        label: nil,
        label_question: nil,
        label_question_type:
          case type do
            :text -> "shortAnswer"
            :selection -> "checkbox"
            _ -> nil
          end,
        master_field_id: 0,
        set_value: "",
        default_value: "",
        status: 0,
        flags: 0
      }

      nf = Repo.insert!(new_field)

      cs = IACMasterForm.changeset(master_form, %{fields: master_form.fields ++ [nf.id]})
      Repo.update!(cs)

      # If the field type requires a location, then redirect
      # immediately to the location selection.
      if needs_location? do
        {:ok, nf, true}
      else
        {:ok, nf, false}
      end
    end
  end

  defp make_iac_label(il) do
    %{
      value: il.value,
      question: il.question,
      type:
        if il.company_id == nil do
          "internal"
        else
          "custom"
        end
    }
  end

  def iac_get_labels(conn, _params) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("forbidden")
    else
      labels_m =
        Repo.all(
          from il in IACLabel,
            where: is_nil(il.company_id) or il.company_id == ^requestor.company_id,
            select: il
        )
        |> Enum.map(&make_iac_label/1)

      json(conn, labels_m)
    end
  end

  def iac_label_exists?(label, company_id) do
    case get_iac_label(label, company_id) do
      [] -> false
      _ -> true
    end
  end

  def get_iac_label(label, company_id) do
    Repo.all(
      from il in IACLabel,
        where:
          (is_nil(il.company_id) or il.company_id == ^company_id) and il.status == 0 and
            il.flags == 0 and il.value == ^label,
        select: il
    )
  end

  def iac_get_label(conn, %{"value" => label}) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("forbidden")
    else
      case get_iac_label(label, requestor.company_id) do
        [] -> conn |> put_status(404) |> text("not found")
        [ll] -> json(conn, make_iac_label(ll))
        _ -> conn |> put_status(400) |> text("too many")
      end
    end
  end

  def iac_commit_labels(conn, %{"iacDocId" => iac_doc_id}) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("forbidden")
    else
      iac_doc = Repo.get(IACDocument, iac_doc_id)

      labels =
        IACMasterForm.raw_fields_of(iac_doc)
        |> Enum.map(fn field -> %{label: field.label, question: field.label_question} end)
        |> Enum.uniq()

      for label_field <- labels do
        # check if the label already exists
        # if yes, ignore it, if not, create it
        if not iac_label_exists?(label_field.label, requestor.company_id) do
          Repo.insert!(%IACLabel{
            flags: 0,
            status: 0,
            value: label_field.label,
            question: label_field.question,
            company_id: requestor.company_id,
            inserted_by: requestor.user_id
          })
        end
      end

      text(conn, "OK")
    end
  end

  def iac_get_labels_of_raw_document(conn, %{"rdid" => rdid}) do
    requestor = get_current_requestor(conn)
    rd = Repo.get(RawDocument, rdid)

    if requestor == nil or rd == nil or rd.company_id != requestor.company_id do
      conn |> put_status(403) |> text("forbidden")
    else
      iac_doc = IACDocument.get_for(:raw_document, rd)

      unique_fields =
        IACMasterForm.fields_of(iac_doc)
        |> Enum.map(fn field ->
          field.label
        end)
        |> Enum.uniq()
        |> Enum.filter(&(&1 != ""))

      json(conn, unique_fields)
    end
  end

  # FIXME: this function should update the labels ???
  def iac_put_labels(conn, %{"labels" => labels}) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("forbidden")
    else
      labels
      |> Enum.each(fn _label ->
        # TODO(lev/9189): finish committing the labels
        nil
      end)

      text(conn, "OK")
    end
  end

  # Asked to do a signature on the IACfield ifid for the RawDocument TID
  # This is used during IAC Setup to setup a default, saved signature
  # These also have to abide by the ESIGN requirements.
  #  rr = requestor if isreq or recipient
  def api_set_signature(rr, ifid, sig_dataurl, isreq, remote_ip, save, _rid, signee) do
    field = Repo.get(IACField, ifid)

    extra_flags =
      if isreq == "true" or isreq == true do
        [:requestor]
      else
        []
      end

    # TODO: audit, check access policy

    # Check if a signature already exists for this field
    iacsig = Repo.get_by(IACSignature, signature_field: field.id)
    signee_version = signee.version

    signee_type =
      if signee_version > 0 do
        signee.type
      else
        0
      end

    signee_id =
      if signee_version > 0 do
        signee.id
      else
        0
      end

    iacsig =
      if iacsig != nil do
        # We are overriding existing signature, start by getting the current structure
        cs =
          IACSignature.changeset(iacsig, %{
            signature_file: sig_dataurl,
            audit_ip: remote_ip,
            audit_user: rr.user_id,
            audit_sign_start: DateTime.utc_now() |> DateTime.truncate(:second),
            audit_sign_end: DateTime.utc_now() |> DateTime.truncate(:second),
            status: 0,
            flags: IACSignature.flags([:dataurl] ++ extra_flags),
            signee_version: signee_version,
            signee_type: signee_type,
            signee_id: signee_id
          })

        Repo.update!(cs)

        iacsig
      else
        # We are creating a new signature
        iacsig = %IACSignature{
          signature_file: sig_dataurl,
          signature_field: field.id,
          audit_ip: remote_ip,
          audit_user: rr.user_id,
          audit_sign_start: DateTime.utc_now() |> DateTime.truncate(:second),
          audit_sign_end: DateTime.utc_now() |> DateTime.truncate(:second),
          status: 0,
          flags: IACSignature.flags([:dataurl] ++ extra_flags),
          signee_version: signee_version,
          signee_type: signee_type,
          signee_id: signee_id
        }

        Repo.insert!(iacsig)
      end

    # Save the Signature to the User
    if save do
      if isreq do
        cs = Requestor.changeset(rr, %{esign_saved_signature: sig_dataurl})
        Repo.update!(cs)
      else
        cs = Recipient.changeset(rr, %{esign_saved_signature: sig_dataurl})
        Repo.update!(cs)
      end
    end

    iacsig = Repo.get(IACSignature, iacsig.id)
    iacsighash = gen_iac_sighash_for(iacsig)

    # Store the hash for later verification
    iacsh = Repo.get_by(IACSignatureHash, signature_id: iacsig.id)

    iacsh =
      if iacsh == nil do
        new_iacsh = %IACSignatureHash{
          signature_hash: iacsighash,
          signature_id: iacsig.id,
          audit_ip: iacsig.audit_ip,
          audit_user: iacsig.audit_user,
          audit_sign_start: iacsig.audit_sign_start,
          audit_sign_end: iacsig.audit_sign_end,
          status: 0,
          flags: 0
        }

        Repo.insert!(new_iacsh)
      else
        cs =
          IACSignatureHash.changeset(iacsh, %{
            signature_hash: iacsighash,
            signature_id: iacsig.id,
            audit_ip: iacsig.audit_ip,
            audit_user: iacsig.audit_user,
            audit_sign_start: iacsig.audit_sign_start,
            audit_sign_end: iacsig.audit_sign_end,
            status: 0,
            flags: 0
          })

        Repo.update!(cs)
      end

    # Insert an AuditLog Item
    eai = %EsignAuditItem{
      creator_type:
        EsignAuditItem.atom_to_creator_type(
          if isreq do
            :requestor
          else
            :recipient
          end
        ),
      item_data: "#{iacsh.signature_hash}",
      item_type: EsignAuditItem.atom_to_item_type(:signature),
      # XXX: fixme
      # company_id: 0,
      # iaf_id: 0,
      field_id: field.id,
      requestor_id:
        if isreq do
          rr.id
        else
          nil
        end,
      recipient_id:
        if isreq do
          nil
        else
          rr.id
        end,
      ip_address: iacsig.audit_ip,
      status: 0,
      flags: 0
    }

    Repo.insert!(eai)

    :ok
  end

  def api_del_signature(user, fill_type, signature_ids) when is_list(signature_ids) do
    company = Repo.get(Company, user.company_id)
    if AccessPolicy.has_admin_access_to_fill_type_user?(company, user, fill_type) do
      AuditLog.audit(:signatureDel)

      fill_type_filter = [IACField.text_to_fill_type(fill_type)] ++ [0]

      # allow del the user signatures and the anyone
      final_sig_ids = Repo.all(from field in IACField, where: field.id in ^signature_ids and field.fill_type in ^fill_type_filter, select: field.id)

      rows_deleted =
        from(iacsign in IACSignature, where: iacsign.signature_field in ^final_sig_ids)
        |> Repo.delete_all()
        |> elem(0)

      if rows_deleted > 0 do
        AuditLog.audit(:successSignatureDelete, rows_deleted)
        :deleted
      else
        :no_record_deleted
      end
    else
      AuditLog.audit(:signatureDelForbid)
      :forbidden
    end
  end

  def api_del_signature(user, fill_type, signature_ids) when is_binary(signature_ids) do
    sig_list =
      signature_ids
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    api_del_signature(user, fill_type, sig_list)
  end

  #
  # Save the location data into the IACField
  #
  def get_iaf_for_ifexists(recipient, company, iac_doc, contents, _imf) do
    iaf =
      Repo.get_by(IACAssignedForm, %{
        recipient_id: recipient.id,
        company_id: company.id,
        master_form_id: iac_doc.master_form_id,
        contents_id: contents.id,
        status: 0
      })

    if iaf == nil do
      %{flags: 0}
    else
      iaf
    end
  end

  def get_iaf_for(recipient, company, iac_doc, contents, imf) do
    # Check if the IACAssignedForm was created or not before.
    iaf =
      Repo.get_by(IACAssignedForm, %{
        recipient_id: recipient.id,
        company_id: company.id,
        master_form_id: iac_doc.master_form_id,
        contents_id: contents.id,
        status: 0
      })

    iaf =
      if iaf == nil do
        # If the assigned form has not been made, make it now by cloning all
        # IACFields into the hierarchy of the IAF.
        pre = %IACAssignedForm{
          company_id: company.id,
          contents_id: contents.id,
          master_form_id: imf.id,
          recipient_id: recipient.id,
          fields: [],
          status: 0,
          flags: 0
        }

        newiaf = Repo.insert!(pre)

        # Now, we have to clone the master fields from the IACMF.
        imf_fields =
          imf.fields
          |> Enum.map(&Repo.get(IACField, &1))
          |> Enum.filter(&IACField.displayable_field?(&1))
          |> Enum.map(& &1.id)

        new_fields =
          for master_field_id <- imf_fields do
            master_field = Repo.get(IACField, master_field_id)

            slave_field = %IACField{
              parent_id: newiaf.id,
              parent_type: IACField.atom_to_parent_type(:assigned_form),
              name: master_field.name,
              location_type: master_field.location_type,
              location_value_1: master_field.location_value_1,
              location_value_2: master_field.location_value_2,
              location_value_3: master_field.location_value_3,
              location_value_4: master_field.location_value_4,
              location_value_5: master_field.location_value_5,
              location_value_6: master_field.location_value_6,
              field_type: master_field.field_type,
              fill_type: master_field.fill_type,
              master_field_id: master_field.id,
              set_value: master_field.set_value,
              default_value: master_field.default_value,
              internal_value_1: master_field.internal_value_1,
              label: master_field.label,
              label_value: master_field.label_value,
              label_question: master_field.label_question,
              label_question_type: master_field.label_question_type,
              status: master_field.status,
              flags: master_field.flags,
              repeat_entry_form_id: master_field.repeat_entry_form_id,
              allow_multiline: master_field.allow_multiline
            }

            nslave_field = Repo.insert!(slave_field)
            nslave_field.id
          end

        cs =
          IACAssignedForm.changeset(newiaf, %{
            fields: new_fields
          })

        Repo.update!(cs)
      else
        iaf
      end

    iaf
  end

  def do_verify_signature(conn, %{"sighash" => sighash}) do
    # fixup sighash
    new_sighash =
      String.replace(sighash, "#{Application.get_env(:boilerplate, :iac_profile)}-", "")

    iacsighash = Repo.get_by(IACSignatureHash, %{signature_hash: new_sighash})

    if iacsighash == nil do
      BoilerPlateWeb.StormwindController.bad_signature(conn, %{})
    else
      signer_user = BoilerPlate.Repo.get(BoilerPlate.User, iacsighash.audit_user)
      signer_name = signer_user.name
      signer_email = signer_user.email
      document = BoilerPlateWeb.IACView.sighash_to_document(iacsighash)

      title =
        if is_nil(document) do
          ""
        else
          document.name
        end

      BoilerPlateWeb.StormwindController.ok_signature(
        conn,
        %{
          signer_name: signer_name,
          signer_email: signer_email,
          audit_ip: iacsighash.audit_ip,
          inserted_at: iacsighash.inserted_at,
          document_title: title
        }
      )
    end
  end

  def create_or_update_ses_exportable(checklist_id, raw_docs, company) do
    all_ies =
      Repo.all(
        from ise in IACSESExportable,
          where: ise.checklist_id == ^checklist_id and ise.status == 0,
          select: ise
      )

    # Apply deletes
    for erd <- all_ies do
      unless erd.raw_document_id in raw_docs do
        Repo.delete!(erd)
      end
    end

    results =
      for rd <- raw_docs do
        create_or_update_ses_exportable_one(checklist_id, rd, company)
      end

    Enum.reduce(results, {:ok, 0}, fn x, _acc ->
      case x do
        {:ok, _} -> {:ok, 0}
        _ -> {:error, "something bad"}
      end
    end)
  end

  def create_or_update_ses_exportable_one(checklist_id, raw_document_id, company) do
    # check if an IES exists already
    ies =
      Repo.get_by(IACSESExportable, %{
        checklist_id: checklist_id,
        raw_document_id: raw_document_id,
        status: 0
      })

    IO.puts("create_or_update_ses_exportable_one #{checklist_id} #{raw_document_id}")

    if ies == nil do
      create_ses_exportable(checklist_id, raw_document_id, company)
    else
      # update_ses_exportable(ies, checklist_id, raw_document_id, company)
      {:ok, ies.id}
    end
  end

  def update_ses_exportable(ies, _checklist_id, raw_document_id, _company) do
    raw_document = Repo.get(RawDocument, raw_document_id)
    iac_document = IACDocument.get_for(:raw_document, raw_document)

    if iac_document == nil do
      {:error, :no_iac_doc_found}
    else
      iac_document_id = iac_document.id

      # find the target checklist
      internal_pkg = Repo.get(Package, ies.target_checklist_id)

      if internal_pkg == nil do
        raise ArgumentError, message: "invalid state for IES #{ies.id}, TCHK is bad"
      end

      # Update the target checklist to contain the new raw document
      Repo.update!(
        Package.changeset(internal_pkg, %{
          templates: [raw_document_id],
          title: "internal_package_#{raw_document_id}"
        })
      )

      # Update IES
      Repo.update!(
        IACSESExportable.changeset(ies, %{
          raw_document_id: raw_document_id,
          iac_document_id: iac_document_id
        })
      )

      # We're done
      {:ok, ies.id}
    end
  end

  def create_ses_exportable(checklist_id, raw_document_id, company) do
    raw_document = Repo.get(RawDocument, raw_document_id)
    iac_document = IACDocument.get_for(:raw_document, raw_document)

    if iac_document == nil do
      {:error, :no_iac_doc_found}
    else
      iac_document_id = iac_document.id

      # Create the internal checklist
      internal_pkg =
        Repo.insert!(%Package{
          title: "internal_package_#{raw_document_id}",
          description: "INTERNAL DO NOT SEND",
          company_id: company.id,
          templates: [raw_document_id],
          status: 0,
          allow_duplicate_submission: false,
          allow_multiple_requests: false,
          is_archived: true,
          enforce_due_date: false,
          due_date_type: 1,
          due_days: nil
        })

      target_checklist_id = internal_pkg.id

      # Insert the SES Structure
      ise =
        Repo.insert!(%IACSESExportable{
          version: 0,
          contents_id: nil,
          checklist_id: checklist_id,
          target_checklist_id: target_checklist_id,
          iac_document_id: iac_document_id,
          raw_document_id: raw_document_id,
          status: 0,
          flags: 0
        })

      {:ok, ise.id}
    end
  end

  def copy_ses_exportable_to_contents(contents_id, checklist_id) do
    all_ies =
      Repo.all(
        from ise in IACSESExportable,
          where: ise.checklist_id == ^checklist_id and ise.status == 0,
          select: ise
      )

    if all_ies == nil or all_ies == [] do
      {:error, :no_ies_found}
    else
      ies_ids =
        for ies <- all_ies do
          new_ies =
            Repo.insert!(%IACSESExportable{
              version: ies.version,
              contents_id: contents_id,
              checklist_id: nil,
              target_checklist_id: ies.target_checklist_id,
              iac_document_id: ies.iac_document_id,
              raw_document_id: ies.raw_document_id,
              status: ies.status,
              flags: ies.flags
            })

          new_ies.id
        end

      {:ok, ies_ids}
    end
  end

  def ses_get_struct(:checklist, checklist_id) do
    ies =
      Repo.all(
        from ise in IACSESExportable,
          where: ise.checklist_id == ^checklist_id and ise.status == 0 and ise.version == 0,
          select: ise
      )

    if ies != nil and ies != [] do
      %{
        allow: true,
        sesTargetId: Enum.map(ies, & &1.raw_document_id),
        sesTargetName:
          Enum.map(ies, fn i ->
            Repo.get(RawDocument, i.raw_document_id).name
          end)
      }
    else
      %{
        allow: false,
        sesTargetId: [],
        sesTargetName: []
      }
    end
  end

  def ses_get_struct(:contents, contents_id) do
    ies =
      Repo.all(
        from ise in IACSESExportable,
          where: ise.contents_id == ^contents_id and ise.status == 0 and ise.version == 0,
          select: ise
      )

    if ies != nil and not Enum.empty?(ies) do
      %{
        allow: true,
        sesTargetId: Enum.map(ies, & &1.raw_document_id),
        sesTargetName:
          Enum.map(ies, fn i ->
            Repo.get(RawDocument, i.raw_document_id).name
          end)
      }
    else
      %{
        allow: false,
        sesTargetId: [],
        sesTargetName: []
      }
    end
  end

  def api_generate_pdf(requestor, recipient, company, iac_doc, contents, imf, true_contents) do
    iaf = get_iaf_for_ifexists(recipient, company, iac_doc, contents, imf)

    cond do
      iaf == nil ->
        {:error, :missing_iaf}

      requestor.company_id != recipient.company_id ->
        {:error, :forbidden}

      True ->
        fields = IACAssignedForm.fields_of(iaf)

        appendices =
          if true_contents != nil do
            form_ids = true_contents.forms

            Repo.all(
              from iax in IACAppendix,
                where:
                  iax.iac_assigned_form_id == ^iaf.id and iax.status == 0 and iax.version == 0 and
                    iax.form_id in ^form_ids,
                order_by: [asc: iax.appendix_order],
                select: iax
            )
          else
            Repo.all(
              from iax in IACAppendix,
                where:
                  iax.iac_assigned_form_id == ^iaf.id and iax.status == 0 and iax.version == 0 and
                    is_nil(iax.form_id),
                order_by: [asc: iax.appendix_order],
                select: iax
            )
          end

        # IAC/SES: 7373//C21 case: SES mode
        pdf_data = make_bp01(make_data(fields), iac_doc, nil, appendices)

        # Create a new temporary file
        {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate")
        File.write!(tmp_pdf_path, pdf_data)

        template_fn = UUID.uuid4() <> Path.extname("whatever.pdf")

        {_status, _final_path} =
          Document.store(%{
            filename: template_fn,
            path: tmp_pdf_path
          })

        now = DateTime.utc_now()
        now_str = now |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC")

        repeat_reference_name =
          if contents.recipient_description != nil do
            "-#{contents.recipient_description}"
          else
            ""
          end

        name = "#{IACDocument.name_of(iac_doc)}#{repeat_reference_name} - #{now_str}"

        cabinet = %Cabinet{
          name: name,
          recipient_id: recipient.id,
          requestor_id: requestor.id,
          company_id: company.id,
          filename: template_fn,
          status: 0,
          flags: 0
        }

        Repo.insert!(cabinet)

        # Updated the Cabinet, now invalidate the cache
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

        {:ok, template_fn}
    end
  end

  def iac_internal_regenerate(conn, %{"rid" => rid, "aid" => aid, "tid" => tid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    case api_submit_iac(us_user, rid, aid, tid, 0, nil, false) do
      {:ok, base_doc_id, f_n, path} ->
        BoilerPlateWeb.UserController.api_upload_user_document(
          us_user,
          rid,
          aid,
          base_doc_id,
          true,
          %{filename: f_n, path: path}
        )

      _ ->
        conn |> put_status(500) |> text("unknown error")
    end
  end

  @spec api_submit_iac(
          %User{},
          Recipient.id(),
          PackageAssignment.id(),
          IACDocument.id(),
          integer,
          String.t(),
          boolean
        ) :: {:ok, integer, String.t(), String.t()}
  def api_submit_iac(_us_user, rid, aid, tid, iat, ip, redo_audit \\ true) do
    recipient = Repo.get(Recipient, rid)
    iac_doc = Repo.get(IACDocument, tid)
    assignment = Repo.get(PackageAssignment, aid)
    company = Repo.get(Company, recipient.company_id)

    # Generate how the filename will look
    template_fn = UUID.uuid4() <> ".pdf"

    # Find the IACAssignedForm and the associated fields.
    iaf =
      Repo.get_by(IACAssignedForm, %{
        recipient_id: recipient.id,
        company_id: company.id,
        master_form_id: iac_doc.master_form_id,
        contents_id: assignment.contents_id,
        status: 0
      })

    fields = IACAssignedForm.fields_of(iaf)

    # Add the finishing EAI to the document
    # This is when a recipient has submitted the document
    if redo_audit and FunWithFlags.enabled?(:audit_trail_v2) do
      esign_create(:submit_event, iac_doc, iaf, :recipient, recipient, ip)
    end

    # Create the final document and insert a Document into the database
    # with the final document.
    body =
      if FunWithFlags.enabled?(:audit_trail_v2) do
        # 7373: Only make the audit trail if countersign is not enabled for this document,
        #       as the audit trail will be created at the end of the countersign operation.
        if IACDocument.is_countersign(iac_doc) do
          make_bp01(make_data(fields), iac_doc, nil)
        else
          make_bp01(make_data(fields), iac_doc, make_audit_trail(iaf, fields, iat, ip))
        end
      else
        make_bp01(make_data(fields), iac_doc, make_audit_trail(iaf, fields, iat, ip))
      end

    # Create a new temporary file
    {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate")
    File.write!(tmp_pdf_path, body)

    # Handoff work
    {:ok, IACDocument.base_document_id(iac_doc), template_fn, tmp_pdf_path}
  end

  def esign_update_or_create(:open_event, _iac_doc, iaf, :recipient, recipient, ip) do
    if not FunWithFlags.enabled?(:audit_trail_v2) do
      raise ArgumentError,
        message: "Called esign_update_or_create without FF#audit_trail_v2 enabled"
    end

    item_type_open = EsignAuditItem.atom_to_item_type(:opened_document)

    eai =
      Repo.one(
        from e in EsignAuditItem,
          where:
            e.iaf_id == ^iaf.id and e.recipient_id == ^recipient.id and e.status == 0 and
              e.item_type == ^item_type_open,
          order_by: [desc: e.inserted_at],
          limit: 1,
          select: e
      )

    now_ts = DateTime.utc_now() |> DateTime.to_unix()

    if eai == nil do
      # This document was never opened - so create a new record
      eai = %EsignAuditItem{
        creator_type: EsignAuditItem.atom_to_creator_type(:recipient),
        item_data: Poison.encode!(%{timestamp: now_ts}),
        item_type: EsignAuditItem.atom_to_item_type(:opened_document),
        iaf_id: iaf.id,
        field_id: nil,
        requestor_id: nil,
        recipient_id: recipient.id,
        ip_address: ip,
        status: 0,
        flags: 0
      }

      Repo.insert!(eai)
    else
      # This doucment was opened before - update the existing record
      cs =
        EsignAuditItem.changeset(eai, %{
          item_data: Poison.encode!(%{timestamp: now_ts}),
          ip_address: ip
        })

      Repo.update!(cs)
    end
  end

  def esign_update_or_create(:open_event, _iac_doc, iaf, :requestor, requestor, ip) do
    if not FunWithFlags.enabled?(:audit_trail_v2) do
      raise ArgumentError,
        message: "Called esign_update_or_create without FF#audit_trail_v2 enabled"
    end

    item_type_open = EsignAuditItem.atom_to_item_type(:opened_document)

    eai =
      Repo.one(
        from e in EsignAuditItem,
          where:
            e.iaf_id == ^iaf.id and e.requestor_id == ^requestor.id and e.status == 0 and
              e.item_type == ^item_type_open,
          order_by: [desc: e.inserted_at],
          limit: 1,
          select: e
      )

    now_ts = DateTime.utc_now() |> DateTime.to_unix()

    if eai == nil do
      # This document was never opened - so create a new record
      eai = %EsignAuditItem{
        creator_type: EsignAuditItem.atom_to_creator_type(:requestor),
        item_data: Poison.encode!(%{timestamp: now_ts}),
        item_type: EsignAuditItem.atom_to_item_type(:opened_document),
        iaf_id: iaf.id,
        field_id: nil,
        requestor_id: requestor.id,
        recipient_id: nil,
        ip_address: ip,
        status: 0,
        flags: 0
      }

      Repo.insert!(eai)
    else
      # This doucment was opened before - update the existing record
      cs =
        EsignAuditItem.changeset(eai, %{
          item_data: Poison.encode!(%{timestamp: now_ts}),
          ip_address: ip
        })

      Repo.update!(cs)
    end
  end

  def esign_create(:submit_event, _iac_doc, iaf, :requestor, requestor, ip) do
    now_ts = DateTime.utc_now() |> DateTime.to_unix()

    eai = %EsignAuditItem{
      creator_type: EsignAuditItem.atom_to_creator_type(:requestor),
      item_data: Poison.encode!(%{timestamp: now_ts}),
      item_type: EsignAuditItem.atom_to_item_type(:submitted_document),
      iaf_id: iaf.id,
      field_id: nil,
      requestor_id: requestor.id,
      recipient_id: nil,
      ip_address: ip,
      status: 0,
      flags: 0
    }

    Repo.insert!(eai)
  end

  def esign_create(:submit_event, _iac_doc, iaf, :recipient, recipient, ip) do
    now_ts = DateTime.utc_now() |> DateTime.to_unix()

    eai = %EsignAuditItem{
      creator_type: EsignAuditItem.atom_to_creator_type(:recipient),
      item_data: Poison.encode!(%{timestamp: now_ts}),
      item_type: EsignAuditItem.atom_to_item_type(:submitted_document),
      iaf_id: iaf.id,
      field_id: nil,
      recipient_id: recipient.id,
      requestor_id: nil,
      ip_address: ip,
      status: 0,
      flags: 0
    }

    Repo.insert!(eai)
  end

  def make_audit_trail(iaf, fields, iat, ip) do
    recipient = Repo.get(Recipient, iaf.recipient_id)
    login_time = DateTime.from_unix!(iat)

    signatures =
      Enum.filter(fields, &(&1.field_type == 3))
      |> Enum.reduce([], fn field, acc ->
        if FunWithFlags.enabled?(:audit_trail_v2) do
          eai =
            Repo.one(
              from e in EsignAuditItem,
                where: e.field_id == ^field.id and e.status == 0,
                order_by: [desc: e.inserted_at],
                limit: 1,
                select: e
            )

          cond do
            eai == nil ->
              acc

            EsignAuditItem.creator_type_to_atom(eai.creator_type) == :requestor ->
              # This was a requestor signing the field
              eai_req = Repo.get(Requestor, eai.requestor_id)
              eai_user = Repo.get(User, eai_req.user_id)

              acc ++
                [
                  %{
                    name: "#{eai_req.name} <#{eai_user.email}>",
                    action: "Signed a Field",
                    timestamp:
                      eai.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
                    ip_address: eai.ip_address,
                    auxiliary_info:
                      "Signature Hash: #{Application.get_env(:boilerplate, :iac_profile)}-#{eai.item_data}"
                  }
                ]

            EsignAuditItem.creator_type_to_atom(eai.creator_type) == :recipient ->
              # This was a recipient signing the field
              eai_recp = Repo.get(Recipient, eai.recipient_id)
              eai_user = Repo.get(User, eai_recp.user_id)

              acc ++
                [
                  %{
                    name: "#{eai_recp.name} <#{eai_user.email}>",
                    action: "Signed a Field",
                    timestamp:
                      eai.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
                    ip_address: eai.ip_address,
                    auxiliary_info:
                      "Signature Hash: #{Application.get_env(:boilerplate, :iac_profile)}-#{eai.item_data}"
                  }
                ]
          end
        else
          iacsig = Repo.get_by(IACSignature, signature_field: field.id)

          if iacsig != nil do
            iacsighash = Repo.get_by(IACSignatureHash, signature_id: iacsig.id)

            acc ++
              [
                %{
                  name: recipient.name,
                  action: "Signed a Field",
                  timestamp:
                    iacsig.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
                  ip_address: iacsig.audit_ip,
                  auxiliary_info:
                    "Signature Hash: #{Application.get_env(:boilerplate, :iac_profile)}-#{iacsighash.signature_hash}"
                }
              ]
          else
            acc
          end
        end
      end)

    now = DateTime.utc_now()

    if FunWithFlags.enabled?(:audit_trail_v2) do
      open_type = EsignAuditItem.atom_to_item_type(:opened_document)

      eais =
        Repo.all(
          from e in EsignAuditItem,
            where: e.iaf_id == ^iaf.id and e.item_type == ^open_type and e.status == 0,
            select: e
        )

      if Enum.empty?(eais) do
        raise ArgumentError, message: "No open EAI for IAF #{iaf.id}"
      end

      # finish = [
      #   %{
      #     name: "#{eai_recp.name} <#{eai_user.email}>",
      #     action: "Submitted Document",
      #     timestamp: now |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
      #     ip_address: ip,
      #     auxiliary_info: ""
      #   }
      # ]

      openers =
        for eai <- eais do
          {name, email} =
            if eai.creator_type == EsignAuditItem.atom_to_creator_type(:recipient) do
              r = Repo.get(Recipient, eai.recipient_id)
              u = Repo.get(User, r.user_id)

              {r.name, u.email}
            else
              r = Repo.get(Requestor, eai.requestor_id)
              u = Repo.get(User, r.user_id)

              {r.name, u.email}
            end

          data_parsed = Poison.decode!(eai.item_data)

          %{
            name: "#{name} <#{email}>",
            action: "Opened Document",
            timestamp:
              data_parsed["timestamp"]
              |> DateTime.from_unix!()
              |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
            ip_address: eai.ip_address,
            auxiliary_info: ""
          }
        end

      # Now find the finishes
      finish_type = EsignAuditItem.atom_to_item_type(:submitted_document)

      finisher_eais =
        Repo.all(
          from e in EsignAuditItem,
            where: e.iaf_id == ^iaf.id and e.item_type == ^finish_type and e.status == 0,
            select: e
        )

      finishers =
        for eai <- finisher_eais do
          {eai_name, eai_email} =
            if eai.creator_type == EsignAuditItem.atom_to_creator_type(:recipient) do
              r = Repo.get(Recipient, eai.recipient_id)
              u = Repo.get(User, r.user_id)

              {r.name, u.email}
            else
              r = Repo.get(Requestor, eai.requestor_id)
              u = Repo.get(User, r.user_id)

              {r.name, u.email}
            end

          data_parsed = Poison.decode!(eai.item_data)

          %{
            name: "#{eai_name} <#{eai_email}>",
            action: "Submitted Document",
            timestamp:
              data_parsed["timestamp"]
              |> DateTime.from_unix!()
              |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
            ip_address: eai.ip_address,
            auxiliary_info: ""
          }
        end

      full_audit_trail = openers ++ signatures ++ finishers
      full_audit_trail |> Enum.sort_by(& &1.timestamp)
    else
      finish = [
        %{
          name: recipient.name,
          action: "Submitted Document",
          timestamp: now |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
          ip_address: ip,
          auxiliary_info: ""
        }
      ]

      [
        %{
          name: recipient.name,
          action: "Logged In",
          timestamp: login_time |> Timex.format!("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC"),
          ip_address: ip,
          auxiliary_info: ""
        }
      ] ++ signatures ++ finish
    end
  end

  def make_bp01(data, iac_doc, audit_trail) do
    make_bp01(data, iac_doc, audit_trail, nil)
  end

  def make_bp01(data, iac_doc, audit_trail, appendices) do
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    # Construct the final data structure that we pass on.
    bp01 =
      if audit_trail != nil do
        %{
          version: "bp-02",
          audit_trail: audit_trail,
          data: data
        }
      else
        %{
          version: "bp-01",
          data: data
        }
      end

    bp01 =
      if appendices != nil do
        # Download all the appendices
        apxs3 =
          Enum.map(appendices, fn apx ->
            {:ok, apx_path} = Briefly.create(prefix: "boilerplate")

            res =
              @storage_mod.download_file_request(bucket, "uploads/#{apx.appendix_name}", apx_path)

            IO.inspect(res, label: "appendix-s3-download-#{apx.id}")

            %{path: apx_path, reference: apx.appendix_reference, label: apx.appendix_label}
          end)

        IO.inspect(appendices, label: "appendices")
        IO.inspect(apxs3, label: "apxs3")

        Map.put(bp01, :appendices, apxs3)
      else
        bp01
      end

    # Download the actual document from S3
    downloaded_body = @storage_mod.download_file_stream(bucket, "uploads/#{iac_doc.file_name}")

    # Write the JSON to a temporary location
    {:ok, tmp_json_path} = Briefly.create(prefix: "boilerplate")
    File.write!(tmp_json_path, Jason.encode!(bp01))

    IO.inspect(Jason.encode!(bp01))

    # Write the PDF to a temporary location
    {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate")
    File.write!(tmp_pdf_path, downloaded_body)
    IO.inspect(downloaded_body)

    # Write the final location
    {:ok, tmp_final_path} = Briefly.create(prefix: "boilerplate")

    # Spawn the Node helper. Sad. TODO
    # output =
    # "cat #{tmp_pdf_path} | #{Application.get_env(:boilerplate, :iac_node_runcmd)} #{File.cwd() |> elem(1)}/tools/iac/filler/fillOut.js #{tmp_json_path} > #{tmp_final_path}"
    # |> String.to_char_list()
    # |> :os.cmd()
    fillwrap = "#{File.cwd() |> elem(1)}/tools/iac/filler/fillwrap.sh"

    {output, exit_status} =
      System.cmd(fillwrap, [tmp_pdf_path, tmp_json_path, tmp_final_path],
        env: [
          {"NODE_RUN_CMD", Application.get_env(:boilerplate, :iac_node_runcmd)},
          {"PDFTK_RUN_CMD", Application.get_env(:boilerplate, :iac_pdftk_runcmd)}
        ],
        stderr_to_stdout: true
      )

    IO.inspect("Command exit_status: #{exit_status}")

    if exit_status != 0 and FunWithFlags.enabled?(:automatic_bug_filling) do
      BoilerPlateWeb.Router.file_iac_bug(
        fillwrap,
        tmp_pdf_path,
        tmp_json_path,
        tmp_final_path,
        output
      )

      # TODO: notify the user
    end

    IO.inspect(output)

    File.read!(tmp_final_path)
  end

  def make_data(fields) do
    # Create the bp-01 data structure that we can then pass to process the PDF.
    for field <- fields do
      iacsig = Repo.get_by(IACSignature, signature_field: field.id)

      if IACField.int_to_field_type(field.field_type) == :signature and iacsig != nil do
        # For a Signature, the actual data is stored in an IACSignature.
        iacsighash = gen_iac_sighash_for(iacsig)

        %{
          text: iacsig.signature_file,
          type: field.field_type,
          sighash: "#{Application.get_env(:boilerplate, :iac_profile)}-#{iacsighash}",
          signer: Repo.get(User, iacsig.audit_user).name,
          sigts:
            iacsig.updated_at
            |> Timex.format("{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s} UTC")
            |> elem(1),
          top: field.location_value_1,
          left: field.location_value_2,
          width: field.location_value_3,
          height: field.location_value_4,
          page: field.location_value_6
        }
      else
        %{
          text: field.set_value,
          type: field.field_type,
          multiline: field.allow_multiline,
          label: field.label,
          top: field.location_value_1,
          left: field.location_value_2,
          width: field.location_value_3,
          height: field.location_value_4,
          page: field.location_value_6
        }
      end
    end
  end

  def export_iac(conn, %{"tid" => tid}) do
    iac_doc = Repo.get(IACDocument, tid)
    doc_hash = RawDocument.hash_document(Repo.get(RawDocument, iac_doc.document_id))

    fields = IACMasterForm.fields_of(iac_doc)

    fields_data =
      for field <- fields do
        %{
          name: field.name,
          location_type: field.location_type,
          location_value_1: field.location_value_1,
          location_value_2: field.location_value_2,
          location_value_3: field.location_value_3,
          location_value_4: field.location_value_4,
          location_value_5: field.location_value_5,
          location_value_6: field.location_value_6,
          field_type: field.field_type,
          default_value: field.default_value,
          internal_value_1: field.internal_value_1
        }
      end

    json(conn, %{
      "iac-version": 1,
      "boilerplate-version": Application.get_env(:boilerplate, :version),
      document_hash_signature: doc_hash,
      fields: fields_data
    })
  end

  def import_iac(obj, iac_doc, user) do
    # TODO: verify version and other metadata
    # TODO: unify this with IACMasterForm.save/3

    iacmf = %BoilerPlate.IACMasterForm{
      company_id: IACDocument.company_id_of(iac_doc),
      creator_id: user.id,
      fields: [],
      base_pdf: iac_doc.file_name,
      name: IACDocument.name_of(iac_doc),
      description: IACDocument.description_of(iac_doc),
      status: 0,
      flags: 0
    }

    iacmf = Repo.insert!(iacmf)

    ids =
      obj["fields"]
      |> Enum.map(fn raw_field ->
        iacfd = %IACField{
          parent_id: iacmf.id,
          parent_type: IACField.atom_to_parent_type(:master_form),
          name: raw_field["name"],
          location_type: raw_field["location_type"],
          location_value_1: raw_field["location_value_1"] / 1,
          location_value_2: raw_field["location_value_2"] / 1,
          location_value_3: raw_field["location_value_3"] / 1,
          location_value_4: raw_field["location_value_4"] / 1,
          location_value_5: raw_field["location_value_5"] / 1,
          location_value_6: raw_field["location_value_6"] / 1,
          internal_value_1: raw_field["internal_value_1"],
          field_type: raw_field["field_type"],
          master_field_id: 0,
          set_value: "",
          default_value: raw_field["default_value"],
          status: 0,
          flags: 0
        }

        iacfd = Repo.insert!(iacfd)

        iacfd.id
      end)

    # Update the MasterForm for the field ids
    cs =
      BoilerPlate.IACMasterForm.changeset(iacmf, %{
        fields: ids
      })

    Repo.update!(cs)

    # Update the Raw Document
    cs =
      IACDocument.changeset(iac_doc, %{
        master_form_id: iacmf.id
      })

    Repo.update!(cs)

    iacmf.id
  end

  defp in_iac_cache?(hash) do
    cache_filename = "https://bp-iac-masks.s3.us-east-2.amazonaws.com/#{hash}.json"

    result = HTTPoison.head(cache_filename)

    case result do
      {:error, _} -> false
      {:ok, %HTTPoison.Response{status_code: 200}} -> true
      _ -> false
    end
  end

  def api_setup_iac_for_rsdc(_us_user, tid, cid, rid) do
    rsdc = Repo.get(RawDocumentCustomized, tid)
    contents = Repo.get(PackageContents, cid)
    recipient = Repo.get(Recipient, rid)

    iac_doc = IACDocument.get_for(:raw_document_customized, rsdc)

    cond do
      rsdc == nil ->
        {:err, :not_found}

      contents == nil ->
        {:err, :not_found}

      recipient == nil ->
        {:err, :not_found}

      iac_doc == nil ->
        iac_doc = %IACDocument{
          document_type: IACDocument.document_type(:raw_document_customized),
          document_id: rsdc.id,
          file_name: rsdc.file_name,
          master_form_id: nil,
          contents_id: contents.id,
          recipient_id: recipient.id,
          raw_document_id: rsdc.raw_document_id,
          status: 0,
          flags: 0
        }

        n = Repo.insert!(iac_doc)

        {:ok, n}

      true ->
        {:ok, iac_doc}
    end
  end

  def api_setup_iac_for_raw_document(requestor, tid) do
    rd = Repo.get(RawDocument, tid)

    cond do
      requestor == nil ->
        {:err, :forbidden}

      rd == nil ->
        {:err, :not_found}

      rd.company_id != requestor.company_id ->
        {:err, :forbidden}

      true ->
        iac_doc =
          Repo.get_by(IACDocument, %{
            document_type: IACDocument.document_type(:raw_document),
            document_id: tid,
            status: 0
          })

        if iac_doc == nil do
          iac_doc = %IACDocument{
            document_type: IACDocument.document_type(:raw_document),
            document_id: rd.id,
            file_name: rd.file_name,
            master_form_id: nil,
            status: 0,
            flags: 0
          }

          n = Repo.insert!(iac_doc)

          {:ok, n}
        else
          {:ok, iac_doc}
        end
    end
  end

  def api_core_setup_iac(iac_doc, us_user, loadfrom, force, np) do
    iac_doc = Repo.get(IACDocument, iac_doc.id)

    document_hash = "disabled"

    # Determine whether we need to create, or retrieve the form information.
    path =
      cond do
        # Retrieve from the IAC Mask cache
        loadfrom == "cache" -> :cache
        # Ask AWS Textract to figure out
        loadfrom == "aws" -> :aws
        # Just show an empty fieldset
        loadfrom == "empty" -> :empty
        # Try parsing the PDF for AcroForm data
        loadfrom == "acro" -> :acro
        # Retrieve from IACMF, if not available, try :cache, then :acro, finally :aws
        loadfrom == "default" -> :none
        # Default case, as above.
        True -> :none
      end

    case path do
      :none ->
        # Check if the document was setup for IAC, if yes, just load
        # the information from the IACMF.
        #
        # Otherwise, if the document is missing, try with the cache, then AWS.
        if IACDocument.setup?(iac_doc) do
          IO.puts("default ok")
          :ok
        else
          if force == "n" do
            IO.puts("default -> cache")
            api_core_setup_iac(iac_doc, us_user, "cache", "n", np)
          else
            IO.puts("default -> FAILED")
            {:error, :force_failed}
          end
        end

      :cache ->
        # Retrieve the information from the IAC Mask Cache.
        if in_iac_cache?(document_hash) do
          cache_filename = "https://bp-iac-masks.s3.us-east-2.amazonaws.com/#{document_hash}.json"

          %HTTPoison.Response{body: body} = HTTPoison.get!(cache_filename)
          iac_data = Jason.decode!(body)

          iac_data
          |> import_iac(iac_doc, us_user)

          IO.puts("cache -> OK")
          api_core_setup_iac(iac_doc, us_user, "default", "n", np)
        else
          if force == "n" do
            IO.puts("cache -> acro")
            api_core_setup_iac(iac_doc, us_user, "acro", "n", np)
          else
            IO.puts("cache -> FAILED")
            {:error, :force_failed}
          end
        end

      :empty ->
        iac_data = %{"fields" => []}

        iac_data
        |> import_iac(iac_doc, us_user)

        IO.puts("empty -> OK")
        api_core_setup_iac(iac_doc, us_user, "default", "n", np)

      :acro ->
        # Try parsing the PDF for field information
        #
        # Download the file
        bucket = Application.get_env(:boilerplate, :s3_bucket)

        downloaded_body =
          @storage_mod.download_file_stream(bucket, "uploads/#{iac_doc.file_name}")

        # Write the file to a location
        {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate", extname: ".pdf")
        # {:ok, tmp_pdf_path} = {:ok, "/tmp/lev-pdf.pdf"}
        File.write!(tmp_pdf_path, downloaded_body)
        IO.inspect(downloaded_body)

        # Write the final location
        {:ok, tmp_final_path} = Briefly.create(prefix: "boilerplate", extname: ".json")
        # XXX TODO Fix this shit
        # {:ok, tmp_final_path} = {:ok, "/tmp/lev-final.json"}

        the_pre_cmd =
          "#{Application.get_env(:boilerplate, :iac_python_runcmd)} #{File.cwd() |> elem(1)}/tools/iac/boilerplate_tools_iac/acroform_to_mask.py #{tmp_pdf_path} #{tmp_final_path}"

        wrapper = Application.get_env(:boilerplate, :iac_python_runcmd_wrapper, & &1)
        the_cmd = wrapper.(the_pre_cmd)

        IO.inspect(the_cmd)

        output = the_cmd |> String.to_charlist() |> :os.cmd()
        IO.inspect(output)

        final_body = File.read!(tmp_final_path)
        IO.inspect(final_body)

        iac_data = Jason.decode!(final_body)

        if iac_data["state"] == 0 do
          iac_data
          |> import_iac(iac_doc, us_user)

          IO.puts("acro -> OK")
          api_core_setup_iac(iac_doc, us_user, "default", "n", np)
        else
          if force == "n" do
            IO.puts("acro -> empty")
            api_core_setup_iac(iac_doc, us_user, "empty", "n", np)
          else
            IO.puts("acro -> FAILED")
            {:error, :force_failed}
          end
        end
    end
  end
end
