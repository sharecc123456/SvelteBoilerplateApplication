defmodule StorageLocalImpl do
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
end
