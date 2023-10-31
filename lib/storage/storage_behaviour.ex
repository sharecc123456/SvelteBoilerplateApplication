defmodule StorageBehaviour do
  @callback download_file_stream(map(), binary()) :: :ok
  @callback download_file_request(map(), binary(), binary()) :: :ok
  @callback put_file(map(), binary(), binary()) :: :ok
end
