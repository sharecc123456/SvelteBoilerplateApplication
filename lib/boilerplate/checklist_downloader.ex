alias BoilerPlate.Repo
alias BoilerPlate.PackageAssignment
alias BoilerPlate.PackageContents
alias BoilerPlateWeb.FormController

defmodule BoilerPlate.ChecklistDownloader do

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  # common utils
  def write_contents_to_file(contents, dir_path, file_name) do
    file_path = Path.join(dir_path, "#{file_name}")
    File.write!(file_path, contents)
    file_path
  end

  # common utils
  defp tocsv(data_list, filepath) do
    File.write!(filepath,
      data_list
        |> Enum.map(fn x -> Enum.join(Tuple.to_list(x), ",") end)
        |> Enum.join("\n"))
  end

  defp create_data_for_form_types(type, data) do
    if type in ["checkbox"] do
      {data.title, data.values |> Enum.join(" ")}
    else
      {data.title, data.value}
    end
  end

  def create_forms_csv_data(assignment) do
    forms_submissions = FormController.get_forms_for_contents(assignment.contents_id, false, true)

    forms_submissions
      |> Enum.map(fn forms_submission ->
          %{
            "filename" => forms_submission.title,
            "data" => forms_submission.formFields
              |> Enum.map(&(create_data_for_form_types(&1.type, &1)))
            }
    end)
  end

  def write_csv_data_for_forms(%{"data" => form_data, "filename" => filename}, dir_name) do
    filepath = Path.join(dir_name, "#{filename}.csv")
    header = {"Question", "Answer"}

    csv_data = [header] ++ form_data
    tocsv(csv_data, filepath)
    filepath
  end

  defp stream_and_write_downloaded_files(file_name, disp_name, dir_path) do
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    base_path = "uploads"

    extname = Path.extname(file_name)
    downloaded_body = @storage_mod.download_file_stream(bucket, "#{base_path}/#{file_name}")

    file_name = "#{disp_name}#{extname}"

    write_contents_to_file(downloaded_body, dir_path, file_name)
  end

  # common utils
  def zip_files(folder_name, cwd, file_paths) do
    relative_paths = file_paths |> Enum.map(fn x -> String.replace(x, "#{cwd}/", "") end)

    files = relative_paths |> Enum.map(&(String.to_charlist/1))

    {:ok, {_, bin}} = :zip.create(String.to_charlist(folder_name), files, [:memory, {:cwd, cwd}])

    bin
  end

  defp build_downloader_display_name(company, recipient, title, extname) do
    cpn =
      company.name
      |> String.replace(" ", "_")
      |> String.replace(".", "")
      |> String.downcase()

      rcpname =
      if recipient != nil do
        recipient.name
        |> String.replace(" ", "_")
        |> String.replace(".", "")
        |> String.downcase()
      else
        cpn
      end

    "#{rcpname}-#{title |> String.replace(" ", "_") |> String.downcase()}-completed#{extname}"
  end

  defp checklist_folder_name(checklist) do
    if checklist.recipient_description do "#{checklist.title}-[#{checklist.recipient_description}]" else checklist.title end
  end

  def checklist_all_requests_file_paths(base_dir, assignment, contents) do
    folder_name = checklist_folder_name(contents)

    document_files = PackageAssignment.get_completed_checklist_files(assignment)

    # create temp directory to store zip files
    dir_path = Path.join(base_dir, folder_name)

    if not File.exists?(dir_path) do
      File.mkdir(dir_path)
    end

    csv_data_for_assignment = create_forms_csv_data(assignment)

    forms_paths = csv_data_for_assignment |> Enum.map(&write_csv_data_for_forms(&1, dir_path)) |> List.flatten

    file_paths =
      document_files |> Enum.map(fn x -> stream_and_write_downloaded_files(x.filename, x.display_name, dir_path) end)

    {:ok, {forms_paths ++ file_paths, folder_name}}
  end

  def download_completed_checklist(company, assignment, contents, recipient) do
    {:ok, base_dir} = Briefly.create(directory: true)

    {:ok, {all_files, folder_name}} = checklist_all_requests_file_paths(base_dir, assignment, contents)
    disp_name = build_downloader_display_name(company, recipient, folder_name, ".gz")

    zip_content = zip_files(folder_name, base_dir, all_files)
    {zip_content, disp_name}
  end

  def download_recipient_checklists(company, recipient, assignments) do
    {:ok, base_dir} = Briefly.create(directory: true)

    if assignments == [] do
      :forbidden
    else
      all_files =
        assignments
          |> Enum.map(fn assignment ->
              contents = Repo.get(PackageContents, assignment.contents_id)
              {:ok, {all_files, _}} = checklist_all_requests_file_paths(base_dir, assignment, contents)
              all_files
          end
        ) |> List.flatten

      disp_name = build_downloader_display_name(company, recipient, "", ".gz")
      zip_content = zip_files("", base_dir, all_files)
      {zip_content, disp_name}
    end
  end
end
