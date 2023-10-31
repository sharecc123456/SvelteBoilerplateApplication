alias BoilerPlate.StorageProvider
alias BoilerPlate.Repo

defmodule GoogleOauthStorage do
  @behaviour StorageBehaviour

  @impl StorageBehaviour
  def download_file_stream(_bucket, object) do
    File.read!("#{object}")
  end

  @impl StorageBehaviour
  def download_file_request(_bucket, object, target) do
    File.cp!(object, target)
  end

  @impl StorageBehaviour
  def put_file(_bucket, object, target) do
    File.cp!(object, target)

    :ok
  end

  defp store_refresh_token(sp, rf) do
    Repo.update!(
      StorageProvider.changeset(sp, %{
        meta_data: %{refresh_token: rf}
      })
    )
  end

  defp get_client(sp) do
    rf = sp.meta_data["refresh_token"]

    case BoilerPlate.OAuthStrategies.GoogleOAuthStrategy.get_access_token(rf) do
      {:ok, client} ->
        {:ok, client}

      {:new_refresh_token, rf, client} ->
        store_refresh_token(sp, rf)
        {:ok, client}

      {:error, err} ->
        {:error, err}
    end
  end

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  def new_password(length) do
    alphabet = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
    for _ <- 1..length, into: "", do: <<Enum.random(alphabet)>>
  end

  @testing_mode false
  def put_with_storage_provider(sp, filename, vars \\ %{}, rename_to) do
    {:ok, client} = get_client(sp)
    client = APIs.GoogleDrive.new(client.token.access_token)
    bucket = Application.get_env(:boilerplate, :s3_bucket)
    file_body = @storage_mod.download_file_stream(bucket, "uploads/#{filename}")

    if @testing_mode do
      folder = APIs.GoogleDrive.create_folder(client, "Boilerplate Uploads")
      APIs.GoogleDrive.upload_file(client, folder["id"], "*/*", filename, file_body)

      :ok
    else
      folder_id =
        StorageProvider.walk_path(
          sp,
          client,
          sp.path_template,
          vars,
          create: true
        )

      IO.inspect(%{msg: "put_with_storage_provider/gdrive", folder_id: folder_id})

      APIs.GoogleDrive.upload_file(
        client,
        folder_id,
        "*/*",
        rename_to,
        file_body
      )

      :ok
    end
  end
end
