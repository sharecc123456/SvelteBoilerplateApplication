alias BoilerPlate.Repo
alias BoilerPlate.RawDocument
alias BoilerPlate.Document
alias BoilerPlate.RequestCompletion
alias BoilerPlate.DocumentRequest


defmodule BoilerPlate.PackageAssignment do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type id :: integer()

  schema "package_assignments" do
    field :company_id, :integer
    field :flags, :integer
    field :package_id, :integer
    field :recipient_id, :integer
    field :status, :integer
    field :requestor_id, :integer
    field :open_status, :integer
    field :due_date, :utc_datetime_usec
    field :enforce_due_date, :boolean, default: false
    field :docs_downloaded, {:array, :integer}, default: []
    field :contents_id, :integer
    field :due_date_expired, :boolean, default: false
    field :append_note, :string, default: ""
    field :deleted_recipient_id, :integer, default: -1
    field :reminder_state, :map, default: %{last_send_at: nil, total_count: 0, send_by: nil}
    field :delivery_fault, :boolean, default: false
    field :fault_message, :string, default: nil

    timestamps()
  end

  @doc false
  def changeset(package_assignment, attrs) do
    package_assignment
    |> cast(attrs, [
      :recipient_id,
      :company_id,
      :package_id,
      :flags,
      :status,
      :requestor_id,
      :open_status,
      :due_date,
      :enforce_due_date,
      :docs_downloaded,
      :contents_id,
      :due_date_expired,
      :append_note,
      :deleted_recipient_id,
      :reminder_state,
      :delivery_fault,
      :fault_message
    ])
    |> validate_required([:recipient_id, :company_id, :package_id, :flags, :status, :contents_id])
  end

  def status_to_atom(status) do
    case status do
      0 -> :valid
      1 -> :archived
      2 -> :deleted
    end
  end

  def get_company_assignments_count_by_period(company_id, start_time_period, end_time_period) do
    query =
      from pkgassigment in BoilerPlate.PackageAssignment,
        # count repeat submission packages
        where:
          pkgassigment.company_id == ^company_id and
            pkgassigment.inserted_at >= ^start_time_period and
            pkgassigment.inserted_at <= ^end_time_period,
        select: pkgassigment

    Repo.aggregate(query, :count, :id)
  end

  def get_company_docs_processed_count_by_period(company_id, start_time_period, end_time_period) do
    query =
      from pkgassigment in BoilerPlate.PackageAssignment,
        # count repeat submission packages
        where:
          pkgassigment.company_id == ^company_id and
            pkgassigment.inserted_at >= ^start_time_period and
            pkgassigment.inserted_at <= ^end_time_period,
        select: pkgassigment

    Repo.aggregate(query, :count, :id)
  end

  def get_send_company_documents(company_id, start_time_period, end_time_period) do
    subset_query =
      from doc in BoilerPlate.PackageAssignment,
        join: content in BoilerPlate.PackageContents,
        on: content.id == doc.contents_id,
        # count repeat submission packages
        where:
          doc.company_id == ^company_id and fragment("? <> '{}'", content.documents) and
            doc.inserted_at >= ^start_time_period and doc.inserted_at <= ^end_time_period,
        select: %{id: fragment("unnest(?)", content.documents)}

    query =
      from rd in RawDocument,
        join: doc in subquery(subset_query),
        on: doc.id == rd.id,
        select: rd.flags

    Repo.all(query)
  end

  def get_company_documents_count_by_period(
        :rspec,
        company_id,
        start_time_period,
        end_time_period
      ) do
    get_send_company_documents(company_id, start_time_period, end_time_period)
    |> Enum.count(&(&1 == 2))
  end

  def get_company_documents_count_by_period(
        :generic,
        company_id,
        start_time_period,
        end_time_period
      ) do
    get_send_company_documents(company_id, start_time_period, end_time_period)
    |> Enum.count(&(&1 != 2))
  end

  def get_completed_checklist_files(assignment) do
    docs_subquery =
      from doc in Document,
        join: raw_doc in RawDocument,
        on: raw_doc.id == doc.raw_document_id,
        where: doc.assignment_id == ^assignment.id and doc.filename != "",
        select: %{
          raw_doc_id: doc.raw_document_id,
          filename: doc.filename,
          status: doc.status,
          seqNum: row_number() |> over(partition_by: doc.raw_document_id, order_by: doc.inserted_at),
          inserted_at: doc.inserted_at,
          display_name: raw_doc.name
        }

    documents = Repo.all(
      from e in subquery(docs_subquery),
        order_by: [desc: e.inserted_at],
        where: e.seqNum == 1,
        select: e
      )

    request_subquery =
      from doc in RequestCompletion,
        join: req in DocumentRequest,
        on: req.id == doc.requestid,
        where: doc.assignment_id == ^assignment.id and fragment("? = '{}'", req.attributes) and doc.file_name != "",
        select: %{
          request_id: doc.requestid,
          filename: doc.file_name,
          status: doc.status,
          seqNum: row_number() |> over(partition_by: doc.requestid, order_by: doc.inserted_at),
          inserted_at: doc.inserted_at,
          display_name: req.title
        }

    requests = Repo.all(
      from e in subquery(request_subquery),
        order_by: [desc: e.inserted_at],
        where: e.seqNum == 1,
        select: e
      )

    requests ++ documents
  end
end
