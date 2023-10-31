alias BoilerPlate.Repo
alias BoilerPlate.Document
alias BoilerPlate.RawDocument
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlate.AdhocLink
alias BoilerPlate.PackageContents
alias BoilerPlateWeb.FormController
alias BoilerPlate.AssignmentUtils
alias BoilerPlate.Recipient
import Bitwise

defmodule BoilerPlate.Package do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "packages" do
    field :templates, {:array, :integer}
    field :title, :string
    field :description, :string
    field :company_id, :id
    field :status, :integer
    field :allow_duplicate_submission, :boolean, default: false
    field :allow_multiple_requests, :boolean, default: false
    field :is_archived, :boolean, default: false
    field :enforce_due_date, :boolean, default: false
    field :due_date_type, :integer, default: nil
    field :due_days, :integer, default: nil
    field :tags, {:array, :integer}

    # status == 4 => in_progress

    timestamps()
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(
      attrs,
      [
        :title,
        :description,
        :company_id,
        :templates,
        :status,
        :allow_duplicate_submission,
        :allow_multiple_requests,
        :is_archived,
        :enforce_due_date,
        :due_days,
        :due_date_type,
        :tags
      ]
    )
    |> validate_required([:title, :company_id, :templates])
  end

  def all_of(company) do
    cid = company.id

    Repo.all(
      from p in BoilerPlate.Package,
        order_by: p.title,
        where: p.company_id == ^cid and (p.status == 0 or p.status == 4),
        select: p
    )
  end

  def raw_documents_in(package_contents) do
    tlist = package_contents.documents
    Repo.all(from r in RawDocument, where: r.id in ^tlist, select: r)
  end

  def requests_in(package_contents) do
    tlist = package_contents.requests
    Repo.all(from r in DocumentRequest, where: r.id in ^tlist, select: r)
  end

  def rsds_in(package_contents) do
    tlist = package_contents.documents

    Repo.all(from r in RawDocument, where: r.id in ^tlist, select: r)
    |> Enum.filter(&((&1.flags &&& 2) != 0))
  end

  # Construct a list of documents for use in emails
  def construct_list_for_email(contents) do
    (for doc <- raw_documents_in(contents) do
       "  - #{doc.name}"
     end
     |> Enum.join("\n")) <>
      "\n" <>
      (for req <-
             Repo.all(
               from r in DocumentRequest,
                 where: r.id in ^contents.requests and r.status == 0,
                 select: r
             ) do
         "  - #{req.title}"
       end
       |> Enum.join("\n"))
  end

  def construct_list_for_email_html(contents) do
    (for doc <- raw_documents_in(contents) do
       "  <li>#{doc.name}</li>"
     end
     |> Enum.join("\n")) <>
      (for req <-
             Repo.all(
               from r in DocumentRequest,
                 where: r.id in ^contents.requests and r.status == 0,
                 select: r
             ) do
         "  <li>#{req.title}</li>"
       end
       |> Enum.join("\n"))
  end

  def construct_list_for_remind_now_email(pkgList) do
    for assign <- pkgList do
      contents = Repo.get(PackageContents, assign.contents_id)
      contents.title
    end
  end

  def check_if_doc_completed_by?(content_id, assignment_id, recipient_id) do
    content_docs = Repo.get(PackageContents, content_id).documents

    content_docs
    |> Enum.map(fn raw_doc_id ->
      submitted_doc =
        from(doc in Document,
          where:
            doc.raw_document_id == ^raw_doc_id and doc.assignment_id == ^assignment_id and
              doc.recipient_id == ^recipient_id and
              (doc.status == 1 or doc.status == 2 or doc.status == 4),
          order_by: [desc: doc.inserted_at],
          limit: 1,
          select: doc.id
        )
        |> Repo.one()

      if submitted_doc == nil do
        false
      else
        true
      end
    end)
    |> Enum.all?(&(&1 == true))
  end

  def check_if_request_completed_by?(content_id, assignment_id, recipient_id) do
    content_requests = Repo.get(PackageContents, content_id).requests

    # exclude additional file uploads
    requests =
      from(doc in DocumentRequest,
        where: doc.id in ^content_requests and doc.flags != 4,
        select: doc.id
      )
      |> Repo.all()

    requests
    |> Enum.map(fn request_id ->
      submitted_req =
        from(doc in RequestCompletion,
          # send to review, completed or missing
          where:
            doc.requestid == ^request_id and doc.assignment_id == ^assignment_id and
              doc.recipientid == ^recipient_id and
              (doc.status == 1 or doc.status == 2 or doc.status == 5),
          order_by: [desc: doc.inserted_at],
          limit: 1,
          select: doc.id
        )
        |> Repo.one()

      if submitted_req == nil do
        false
      else
        true
      end
    end)
    |> Enum.all?(&(&1 == true))
  end

  def check_if_assignment_completed_reviews?(assignment) do
    contents = Repo.get(PackageContents, assignment.contents_id)
    recipient = Repo.get(Recipient, assignment.recipient_id)

    document_requests =
      AssignmentUtils.get_checklist_document_requests(assignment, recipient, contents)

    file_requests = AssignmentUtils.get_checklist_file_requests(assignment, recipient, contents)
    forms = FormController.get_forms_for_contents(contents.id)

    a_status = AssignmentUtils.assignment_status(document_requests, file_requests, forms)

    a_status == 2 or a_status == 4
  end

  def check_if_assignment_in_progess?(assign) do
    data = not check_if_assignment_completed_reviews?(assign)
    IO.inspect("Assignment #{assign.id} is in progress?: #{data} ...")
    data
  end

  def check_if_forms_completed_by?(content_id) do
    content_requests = Repo.get(PackageContents, content_id).forms

    content_requests
    |> Enum.map(fn form_id ->
      submitted_forms =
        from(doc in BoilerPlate.FormSubmission,
          where: doc.form_id == ^form_id and doc.contents_id == ^content_id and doc.status != 0,
          select: doc.id
        )
        |> Repo.one()

      if submitted_forms == nil do
        false
      else
        true
      end
    end)
    |> Enum.all?(&(&1 == true))
  end

  def check_if_completed_by(assign, recipient) do
    contents_id = assign.contents_id
    is_all_docs_completed? = check_if_doc_completed_by?(contents_id, assign.id, recipient.id)
    is_all_req_completed? = check_if_request_completed_by?(contents_id, assign.id, recipient.id)
    is_all_forms_completed? = check_if_forms_completed_by?(contents_id)

    is_all_docs_completed? and is_all_req_completed? and is_all_forms_completed?
  end

  def make_adhoc_link(pkg, requestor) do
    adh = %AdhocLink{
      adhoc_string: AdhocLink.generate_string(),
      flags: 0,
      status: 0,
      type: AdhocLink.atom_to_type(:package),
      type_id: pkg.id,
      requestor_id: requestor.id
    }

    a = Repo.insert!(adh)

    {"#{Application.get_env(:boilerplate, :boilerplate_domain)}/adhoc/#{adh.adhoc_string}", a}
  end
end
