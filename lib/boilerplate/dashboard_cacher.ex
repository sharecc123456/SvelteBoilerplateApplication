defmodule BoilerPlate.DashboardCache do
  use GenServer
  require Logger

  # "redis://localhost:6379/3"

  # connect the redis server
  def start_link(_something) do
    redis_host = Application.get_env(:boilerplate, :redis_host)
    redis_port = Application.get_env(:boilerplate, :redis_port)
    url = "redis://#{redis_host}:#{redis_port}"
    GenServer.start_link(__MODULE__, {url})
  end

  def init({url}) do
    Process.register(self(), :dashboard_cache)

    case Redix.start_link(url) do
      {:ok, conn} -> {:ok, conn}
      {:error, err} -> {:error, err}
    end
  end

  # retrieve if exists the cached data
  def get_recipient(pid, key) do
    GenServer.call(pid, {:get_recipient, key})
  end

  def get_contents_review(pid, key, key2) do
    GenServer.call(pid, {:get_contents_review, key, key2})
  end

  # set the cached data for a recipient
  def set_recipient(conn, key, value) do
    GenServer.call(conn, {:set_recipient, key, value})
  end

  # invalidate the cached data for a recipient
  def invalidate_recipient(conn, key) do
    GenServer.call(conn, {:bulk_invalidate_recipient, key})
    GenServer.call(conn, {:invalidate_contents_review, key})
  end

  def invalidate_contents_review(conn, key) do
    GenServer.call(conn, {:invalidate_contents_review, key})
  end

  def set_contents_review(conn, key, key2, value) do
    GenServer.call(conn, {:set_contents_review, key, key2, value})
  end

  # def get_oauth_config(company_id, service, access_token, refresh_token) do
  # end

  @config_env Application.compile_env(:boilerplate, :boilerplate_environment)
  def put_session_log(pid, key, new_entry) do
    if @config_env != :test do
      GenServer.call(pid, {:put_session_log, key, new_entry})
    end
  end

  def get_session_log(pid, key, parse? \\ false) do
    data = GenServer.call(pid, {:get_session_log, key})

    if parse? do
      {:ok, {:ok, log}} = data

      log |> Enum.map(fn x -> Jason.decode!(x) end)
      {:ok, {:ok, log}}
    else
      data
    end
  end

  ##
  ## Internals
  ##

  def handle_call({:put_session_log, key, new_entry}, _from, state) do
    raw_new_entry = Poison.encode!(new_entry)
    {:ok, _} = Redix.command(state, ["LPUSH", "session-log-#{key}", raw_new_entry])
    {:ok, _} = Redix.command(state, ["EXPIRE", "session-log-#{key}", 3600])

    reply = Redix.command(state, ["LTRIM", "session-log-#{key}", 0, 99])
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:get_session_log, key}, _from, state) do
    reply = Redix.command(state, ["LRANGE", "session-log-#{key}", 0, 99])
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:get_recipient, recipient_id}, _from, state) do
    reply = Redix.command(state, ["GET", "recipient-#{recipient_id}"])
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:get_contents_review, recipient_id, contents_id}, _from, state) do
    {:ok, reply} =
      Redix.command(state, ["EXISTS", "contents-review-#{recipient_id}-#{contents_id}"])

    if reply == 0 do
      {:reply, {:ok, {:ok, nil}}, state}
    else
      reply =
        Redix.command(state, [
          "GET",
          "contents-review-#{recipient_id}-#{contents_id}"
        ])

      {:reply, {:ok, reply}, state}
    end
  end

  def handle_call({:set_recipient, recipient_id, value}, _from, state) do
    value = Poison.encode!(value)
    reply = Redix.command(state, ["SET", "recipient-#{recipient_id}", value])
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:set_contents_review, recipient_id, contents_id, value}, _from, state) do
    value = Poison.encode!(value)

    reply = Redix.command(state, ["SET", "contents-review-#{recipient_id}-#{contents_id}", value])

    {:reply, {:ok, reply}, state}
  end

  def handle_call({:bulk_invalidate_recipient, recipient_id}, _from, state) do
    recipient_key = "recipient-#{recipient_id}"
    {:ok, filter_keys} = Redix.command(state, ["KEYS", "#{recipient_key}-*"])
    keys = filter_keys ++ [recipient_key]
    reply = keys |> Enum.each(&Redix.command(state, ["DEL", &1]))
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:invalidate_recipient, recipient_id}, _from, state) do
    reply = Redix.command(state, ["DEL", "recipient-#{recipient_id}"])
    {:reply, {:ok, reply}, state}
  end

  def handle_call({:invalidate_contents_review, recipient_id}, _from, state) do
    recipient_key = "contents-review-#{recipient_id}"
    {:ok, filter_keys} = Redix.command(state, ["KEYS", "#{recipient_key}-*"])
    keys = filter_keys ++ [recipient_key]
    reply = keys |> Enum.each(&Redix.command(state, ["DEL", &1]))
    {:reply, {:ok, reply}, state}
  end
end
