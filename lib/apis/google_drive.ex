defmodule APIs.GoogleDrive do
  def new(access_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://www.googleapis.com"},
      {Tesla.Middleware.BearerAuth, token: access_token},
      Tesla.Middleware.JSON
    ])
  end

  def create_folder(client, folder_name, parent_id \\ 0) do
    case Tesla.post(client, "/drive/v3/files", %{
           mimeType: "application/vnd.google-apps.folder",
           name: folder_name,
           parents: [
             parent_id
           ]
         }) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            resp.body

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end

  def create_file(client, file_name, parent_id, mime_type) do
    case Tesla.post(client, "/drive/v3/files", %{
           mimeType: mime_type,
           name: file_name,
           parents: [
             parent_id
           ]
         }) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            resp.body

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end

  def check_folder_exists(client, parent, segment) do
    case Tesla.get(
           client,
           "/drive/v3/files?q=\"#{parent}\"+in+prents&fields=files(name)"
         ) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            Enum.find(resp.body["files"], fn x ->
              x["name"] == segment
            end)

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end

  def upload_file(client, parent_id, mimeType, filename, body) do
    metadata =
      Poison.encode!(%{
        name: filename,
        parents: [parent_id],
        mimeType: mimeType
      })

    mp =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_file_content(metadata, "",
        headers: [
          {"content-type", "application/json"}
        ]
      )
      |> Tesla.Multipart.add_file_content(body, "test.txt",
        headers: [
          {"content-type", mimeType}
        ]
      )

    case Tesla.post(client, "/upload/drive/v3/files?uploadType=multipart", mp) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            resp.body

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end
end
