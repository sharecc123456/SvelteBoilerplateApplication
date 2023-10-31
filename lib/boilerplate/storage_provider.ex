alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.RawDocument
alias BoilerPlate.DocumentRequest
require Logger

defmodule BoilerPlate.StorageProvider do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_backends ["s3", "egnyte", "gdrive", "box"]

  schema "storage_providers" do
    field :backend, :string, default: "s3"
    field :path_template, :string, default: "/Boilerplate Uploads"
    field :auto_export, :boolean, default: true
    field :meta_data, :map, default: %{}
    field :status, :integer, default: 0
    field :flags, :integer, default: 0
    timestamps()
  end

  @doc false
  def changeset(sp, attrs) do
    sp
    |> cast(attrs, [:backend, :meta_data, :status, :flags, :path_template, :auto_export])
    |> validate_number(:flags, equal_to: 0)
    |> validate_number(:status, less_than: 2, greater_than_or_equal_to: 0)
    |> validate_inclusion(:backend, @valid_backends)
    |> validate_required([:backend, :meta_data, :status, :flags])
  end

  def type_valid?(t), do: Enum.member?(@valid_backends, t)

  def create(attrs \\ []) do
    cs = changeset(%__MODULE__{}, attrs)

    if cs.valid? do
      case Repo.insert(cs) do
        {:ok, s} -> {:ok, s}
        {:error, e} -> {:ecto_error, e}
        _ -> {:error, :unknown}
      end
    else
      {:invalid_changeset, cs}
    end
  end

  def set_for({:ok, sp = %__MODULE__{}}, company, :permanent) do
    Repo.update!(
      BoilerPlate.Company.changeset(company, %{
        permanent_storage_provider: sp.id
      })
    )
  end

  def set_for({:ok, sp = %__MODULE__{}}, company, :temporary) do
    Repo.update!(
      BoilerPlate.Company.changeset(company, %{
        temporary_storage_provider: sp.id
      })
    )
  end

  def update_path_template(company, :permanent, path_template) do
    sp = permanent_of(company)
    Repo.update(changeset(sp, %{path_template: path_template}))
  end

  def update_metadata(company, :permanent, backend, metadata) do
    sp = permanent_of(company)
    Repo.update!(changeset(sp, %{backend: backend, meta_data: metadata}))
  end

  def temporary_of(company) do
    if company.temporary_storage_provider == nil do
      %BoilerPlate.StorageProvider{
        backend: "s3",
        path_template: "",
        meta_data: %{
          "access_key" => Application.get_env(:ex_aws, :access_key_id),
          "secret_key" => Application.get_env(:ex_aws, :secret_access_key),
          "region" => Application.get_env(:ex_aws, :region)
        },
        status: 0,
        flags: 0
      }
    else
      BoilerPlate.Repo.get(BoilerPlate.StorageProvider, company.temporary_storage_provider)
    end
  end

  def permanent_of(company) do
    IO.puts("permanent_of(#{company.id}) => #{company.permanent_storage_provider}")

    if company.permanent_storage_provider == nil do
      %BoilerPlate.StorageProvider{
        backend: "s3",
        path_template: "",
        meta_data: %{
          "access_key" => Application.get_env(:ex_aws, :access_key_id),
          "secret_key" => Application.get_env(:ex_aws, :secret_access_key),
          "region" => Application.get_env(:ex_aws, :region)
        },
        status: 0,
        flags: 0
      }
    else
      BoilerPlate.Repo.get(BoilerPlate.StorageProvider, company.permanent_storage_provider)
    end
  end

  def has_permanent?(company) do
    company.permanent_storage_provider != nil
  end

  def has_temporary?(company) do
    company.temporary_storage_provider != nil
  end

  # Rename the file to something that the user can digest - instead of a UUID.
  defp rename_file(type, item, root_item, vars) do
    ext =
      Path.extname(
        if type == :request_completion do
          item.file_name
        else
          item.filename
        end
      )

    full_name =
      vars.full_name
      |> String.replace(" ", "_")
      |> String.replace(".", "")
      |> String.downcase()

    raw_doc_name =
      if type == :request_completion do
        root_item.title
      else
        root_item.name
      end

    doc_name =
      raw_doc_name
      |> String.replace(" ", "_")
      |> String.replace(".", "")
      |> String.downcase()

    "#{full_name}-#{doc_name}#{ext}"
  end

  def put(_sp, _ftype, _f, _variables \\ %{})
  def put(nil, _, _, _), do: :ok

  def put(sp, :request_completion, request_completion, variables) do
    dr = Repo.get(DocumentRequest, request_completion.requestid)
    should_upload? = dr.attributes != nil and Enum.empty?(dr.attributes)

    if should_upload? do
      rename_to = rename_file(:request_completion, request_completion, dr, variables)

      case sp.backend do
        "s3" ->
          :ok

        "egnyte" ->
          :ok

        "gdrive" ->
          GoogleOauthStorage.put_with_storage_provider(
            sp,
            request_completion.file_name,
            variables,
            rename_to
          )

        "box" ->
          BoxOauthStorage.put_with_storage_provider(
            sp,
            request_completion.file_name,
            variables,
            rename_to
          )
      end
    else
      :ok
    end
  end

  def put(sp, :document, document, variables) do
    rd = Repo.get(RawDocument, document.raw_document_id)
    should_upload? = rd != nil

    if should_upload? do
      rename_to = rename_file(:document, document, rd, variables)

      case sp.backend do
        "s3" ->
          :ok

        "egnyte" ->
          :ok

        "gdrive" ->
          GoogleOauthStorage.put_with_storage_provider(
            sp,
            document.filename,
            variables,
            rename_to
          )

        "box" ->
          BoxOauthStorage.put_with_storage_provider(sp, document.filename, variables, rename_to)
      end
    else
      :ok
    end
  end

  def deauthorize(company, backend) do
    cond do
      not has_permanent?(company) ->
        {:error, :not_found}

      permanent_of(company).backend != backend ->
        {:error, :mismatch}

      true ->
        permanent_of(company)
        |> changeset(%{status: 1})
        |> Repo.update!()

        company
        |> Company.changeset(%{permanent_storage_provider: nil})
        |> Repo.update!()

        :ok
    end
  end

  ###
  ### Path Walking
  ###

  defp folder_exists?(sp, client, segment, parent) do
    case sp.backend do
      "s3" ->
        {:ok, 0}

      "gdrive" ->
        case APIs.GoogleDrive.check_folder_exists(client, parent, segment) do
          {:error, _e} -> {:error, :not_found}
          r -> {:ok, r["id"]}
        end

      "box" ->
        case APIs.Box.check_folder_exists(client, parent, segment) do
          {:error, _e} -> {:error, :not_found}
          nil -> {:error, :not_found}
          r -> {:ok, r["id"]}
        end
    end
  end

  defp create_folder(sp, client, segment, parent) do
    IO.inspect(parent, label: "sp/create_folder/parent")

    case sp.backend do
      "s3" ->
        {:ok, 0}

      "gdrive" ->
        case APIs.GoogleDrive.create_folder(client, segment, parent) do
          {:error, e} ->
            IO.inspect(e, label: "sp/create_folder/gdrive/error")
            {:error, :not_found}

          f ->
            {:ok, f["id"]}
        end

      "box" ->
        case APIs.Box.create_folder(client, segment, parent) do
          {:error, e} ->
            IO.inspect(e, label: "sp/create_folder")
            {:error, :not_found}

          f ->
            {:ok, f["id"]}
        end
    end
  end

  defp walk_segment(sp, client, segment, parent, create) do
    IO.inspect(%{segment: segment, parent: parent}, label: "walk_segment")

    case folder_exists?(sp, client, segment, parent) do
      {:ok, id} ->
        IO.inspect(%{segment: segment, parent: parent, id: id}, label: "walk_segment/ok")
        {:ok, id}

      {:error, :not_found} ->
        IO.inspect(%{segment: segment, parent: parent}, label: "walk_segment/error")

        if create do
          r = create_folder(sp, client, segment, parent)

          IO.inspect(%{segment: segment, parent: parent, r: r}, label: "walk_segment/error/create")

          r
        else
          {:error, :not_found}
        end
    end
  end

  # NOTE: if you add a variable, please add it to UserPreferences.svelte so that
  #       the users can see an example of them. Additionally, you need to make sure
  #       the variables actually exists, you should add your data to _all_ calls made
  #       to StorageProvider.put/4
  @valid_path_variables ["$FULLNAME", "$YEAR", "$MONTH", "$DAY", "$CHECKLIST"]
  defp replace_variable(raw_segment, path_data) do
    if Enum.member?(@valid_path_variables, raw_segment) do
      current_date = DateTime.utc_now()

      case raw_segment do
        "$FULLNAME" -> path_data.full_name || "Unknown User"
        "$YEAR" -> to_string(current_date.year)
        "$MONTH" -> to_string(current_date.month)
        "$DAY" -> to_string(current_date.day)
        "$CHECKLIST" -> path_data.checklist_name || "Unknown Checklist"
        _ -> raise "replace_variable: invalid variable: #{raw_segment}"
      end
    else
      raw_segment
    end
  end

  @doc """
  Walk a `path_template` in the storage provider `sp`, replacing the variables
  with the data in the `path_data`.

  If you pass `create: true`, (by default it's false), then the folders are automatically created.

  NOTE: `path_template` _must_ start with a `/` to denote the root folder.

  Returns the unique identifier of the last path segment depending on the storage provider.
  """
  @default_walk_path_opts [create: false]
  def walk_path(sp, sp_client, path_template, path_data, opts \\ []) do
    %{create: create} = Keyword.merge(@default_walk_path_opts, opts) |> Enum.into(%{})

    root_folder_id =
      case sp.backend do
        "s3" -> 0
        "gdrive" -> "root"
        "box" -> 0
      end

    IO.inspect(root_folder_id, label: "root_folder_id")

    String.split(path_template, "/")
    |> Enum.drop(1)
    |> Enum.reduce(
      root_folder_id,
      fn raw_segment, acc ->
        case acc do
          {:error, e} ->
            {:error, e}

          parent ->
            segment = replace_variable(raw_segment, path_data)

            case walk_segment(sp, sp_client, segment, parent, create) do
              {:ok, id} -> id
              {:error, :not_found} -> {:error, :not_found}
            end
        end
      end
    )
  end
end
