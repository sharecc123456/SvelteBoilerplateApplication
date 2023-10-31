require Logger

defmodule BoilerPlatePlug.Stats do
  @moduledoc """
  This Plug collects statistics data about incoming requests and the response
  time it took for each API call. Then it feeds this data into an ETS cache
  that can then be fetched by an internal API to see the data.
  """

  @behaviour Plug

  @impl Plug
  def init(opts \\ []) do
    opts
  end

  @impl Plug
  def call(conn, _opts) do
    start_time = System.monotonic_time()

    Plug.Conn.register_before_send(
      conn,
      fn conn ->
        stop_time = System.monotonic_time()
        elapsed_ms = convert_duration(stop_time - start_time)

        conn =
          if processed_by_phoenix?(conn) do
            record_time(conn, elapsed_ms)

            record_session_log(conn)
          else
            conn
          end

        conn
      end
    )
  end

  # Record a log for the session
  defp record_session_log(conn) do
    action = action_name(conn)

    session_id = Plug.Conn.get_session(conn, :session_id)

    {conn, session_id} =
      if session_id == nil do
        session_id = :crypto.strong_rand_bytes(16) |> Base.encode16()
        conn = conn |> Plug.Conn.put_session(:session_id, session_id)
        {conn, session_id}
      else
        {conn, session_id}
      end

    current_ts = DateTime.utc_now() |> DateTime.to_unix()
    log_entry = %{action: action, timestamp: current_ts}

    Task.start(fn ->
      BoilerPlate.DashboardCache.put_session_log(:dashboard_cache, session_id, log_entry)
    end)

    conn
  end

  # Record the time it took to complete this request + the response code for
  # telemetry purposes.
  defp record_time(conn, duration) do
    action = action_name(conn)
    status = "#{conn.status}"
    res = :ets.lookup(:boilerplate_stats_plug, action)

    if Enum.empty?(res) do
      :ets.insert(
        :boilerplate_stats_plug,
        {action,
         %{
           calls: 1,
           max_duration: duration,
           min_duration: duration,
           total_duration: duration,
           statuses: Map.new([{status, 1}])
         }}
      )
    else
      entry = Enum.at(res, 0) |> elem(1)

      new_statuses =
        if Map.has_key?(entry.statuses, status) do
          Map.put(entry.statuses, status, entry.statuses[status] + 1)
        else
          Map.put(entry.statuses, status, 1)
        end

      min_duration = min(entry.min_duration, duration)
      max_duration = max(entry.max_duration, duration)

      :ets.insert(
        :boilerplate_stats_plug,
        {action,
         %{
           calls: entry.calls + 1,
           min_duration: min_duration,
           max_duration: max_duration,
           total_duration: entry.total_duration + duration,
           statuses: new_statuses
         }}
      )
    end
  end

  defp action_name(conn) do
    if not Map.has_key?(conn, :private) || conn.private[:phoenix_controller] == nil ||
         conn.private[:phoenix_action] == nil do
      "unknown"
    else
      controller_name = Macro.underscore(conn.private[:phoenix_controller])
      action_name = conn.private[:phoenix_action]

      "#{controller_name}/#{action_name}"
      |> String.split("/")
      |> Enum.drop(1)
      |> Enum.join("/")
      |> String.replace("/", ".")
    end
  end

  def processed_by_phoenix?(conn) do
    Map.has_key?(conn, :private) && conn.private[:phoenix_controller] &&
      conn.private[:phoenix_action]
  end

  def convert_duration(dur) do
    System.convert_time_unit(dur, :native, :microsecond) / 1000
  end
end
