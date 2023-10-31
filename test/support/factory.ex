defmodule BoilerPlate.Factory do
  use ExMachina.Ecto, repo: BoilerPlate.Repo

  def user_factory() do
    %BoilerPlate.User{
      name: sequence(:user_name, &"user i#{&1}"),
      email: sequence(:user_email, &"user_i#{&1}@cetlie.hu"),
      flags: 0,
      organization: sequence(:user_organization, &"user_org_#{&1}"),
      phone_number: sequence(:user_phone, &"+1555#{&1}"),
      verified: true,
      terms_accepted: true,
      password_hash: ""
    }
  end

  def company_factory() do
    %BoilerPlate.Company{
      name: sequence(:company_name, &"Testing #{&1} Co"),
      status: 0,
      flags: 0
    }
  end

  def requestor_factory() do
    %BoilerPlate.Requestor{
      status: 0,
      name: sequence(:requestor_name, &"Requestor #{&1}"),
      organization: sequence(:requestor_organization, &"Requestor Org #{&1}"),
      terms_accepted: true,
      esign_consented: false
    }
  end

  def recipient_factory() do
    %BoilerPlate.Recipient{
      status: 0,
      name: sequence(:recipient_name, &"Recipient #{&1}"),
      organization: sequence(:recipient_organization, &"Recipient Org #{&1}"),
      terms_accepted: true,
      esign_consented: false,
      tags: []
    }
  end

  def recipient_data_factory() do
    %BoilerPlate.RecipientData{
      flags: 0,
      status: 0,
      recipient_id: 0,
      label: sequence(:recipient_data_label, &"recipient_data_label_#{&1}"),
      value: %{
        value: sequence(:recipient_data_value, &"recipient_data_label_#{&1}")
      }
    }
  end

  def raw_document_factory() do
    %BoilerPlate.RawDocument{
      name: sequence(:raw_document_name, &"template_#{&1}"),
      file_name: UUID.uuid4(),
      description: sequence(:raw_document_description, &"template_description_#{&1}"),
      company_id: 0,
      type: 0,
      flags: 0,
      iac_master_id: 0,
      tags: []
    }
  end

  def document_tag_factory() do
    %BoilerPlate.DocumentTag{
      company_id: nil,
      name: sequence(:document_tag_name, &"document_tag_#{&1}"),
      color: "ffffff",
      status: 0,
      sensitive_level: 0
    }
  end

  def packages_factory() do
    %BoilerPlate.Package{
      status: 0,
      company_id: nil,
      templates: [],
      description: sequence(:package_description, &"test_pkg_desc_#{&1}"),
      title: sequence(:package_name, &"test_package_#{&1}"),
      tags: []
    }
  end

  # NOTE: Do not use unless you know what you're doing.
  #       Contents is a complex resource - they need to have
  #       duplicated RSDCs and document requests for one!!
  #
  # USE: ConnCase.insert_contents/3
  def package_contents_factory() do
    %BoilerPlate.PackageContents{
      recipient_id: nil,
      status: 0,
      package_id: nil,
      documents: [],
      requests: [],
      title: sequence(:package_content_name, &"test_package_content_#{&1}"),
      tags: []
    }
  end

  def package_assignments_factory() do
    %BoilerPlate.PackageAssignment{
      recipient_id: nil,
      company_id: nil,
      contents_id: nil,
      package_id: nil,
      flags: 0,
      status: 0
    }
  end

  def notification_factory() do
    %BoilerPlate.Notification{
      message: sequence(:notification, &"test_notification_#{&1}"),
      company_id: nil,
      flags: nil,
      user_id: nil,
      type: "test"
    }
  end

  def iac_document_factory() do
    %BoilerPlate.IACDocument{
      document_type: 0,
      document_id: 0,
      file_name: "",
      master_form_id: nil,
      contents_id: 0,
      recipient_id: 0,
      raw_document_id: 0,
      status: 0,
      flags: 0
    }
  end

  def iac_label_factory() do
    %BoilerPlate.IACLabel{
      flags: 0,
      status: 0,
      value: sequence(:iac_label_value, &"iac_label_#{&1}"),
      question: sequence(:iac_label_question, &"iac_label_question_#{&1}"),
      company_id: nil,
      inserted_by: nil
    }
  end

  def package_assignment_factory() do
    %BoilerPlate.PackageAssignment{
      company_id: nil,
      flags: 0,
      package_id: nil,
      recipient_id: nil,
      status: 0,
      requestor_id: nil,
      open_status: 0,
      due_date: 0,
      contents_id: nil
    }
  end

  def document_request_factory() do
    %BoilerPlate.DocumentRequest{
      packageid: nil,
      title: sequence(:document_request_title, &"document_request_title_#{&1}"),
      status: 0,
      description: sequence(:document_request_description, &"document_request_description_#{&1}"),
      attributes: []
    }
  end

  def request_completion_factory() do
    %BoilerPlate.RequestCompletion{
      recipientid: nil,
      file_name: "",
      status: 0,
      requestid: nil,
      company_id: nil,
      assignment_id: nil
    }
  end

  def form_factory() do
    %BoilerPlate.Form{
      title: sequence(:form_title, &"Form #{&1}"),
      description: sequence(:form_description, &"Form Description #{&1}"),
      package_id: 0
    }
  end

  def form_field_factory() do
    %BoilerPlate.FormField{
      title: sequence(:form_field_title, &"Field #{&1}"),
      type: "shortAnswer",
      required: false,
      order_id: sequence(:form_field_order, & &1),
      form_id: 0
    }
  end

  def cabinet_factory() do
    %BoilerPlate.Cabinet{
      name: sequence(:cabinet_name, &"Cabinet #{&1}"),
      filename: "TEST.PDF"
    }
  end

  def recipient_tags_factory() do
    %BoilerPlate.RecipientTag{
      name: sequence(:recipient_tags, &"Tags #{&1}"),
      company_id: nil,
      status: 0
    }
  end

  def iac_assigned_form_factory() do
    %BoilerPlate.IACAssignedForm{
      company_id: nil,
      contents_id: nil,
      master_form_id: nil,
      recipient_id: nil,
      fields: [],
      status: 0,
      flags: 0,
    }
  end

  def raw_document_customized_factory() do
    %BoilerPlate.RawDocumentCustomized{
      recipient_id: nil,
      contents_id: nil,
      raw_document_id: nil,
      file_name: "TEST_RDC.pdf",
      status: 0,
      flags: 0,
      version: 1,
    }
  end

  ###
  ### Misc Factories
  ###

  @sample_iac_pdf "test/fixtures/bill-of-sale.pdf"
  def upload_factory(attrs) do
    defaults = %{iac: false, file_name: @sample_iac_pdf}
    options = Map.merge(defaults, attrs)
    %{iac: iac, file_name: import_fn} = options

    template_fn = UUID.uuid4() <> Path.extname(import_fn)

    cond do
      iac ->
        File.cp!(import_fn, "uploads/#{template_fn}")

      true ->
        raise ArgumentError, message: "invalid attribute"
    end

    template_fn
  end
end
