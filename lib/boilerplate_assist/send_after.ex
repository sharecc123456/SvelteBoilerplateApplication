defmodule BoilerPlateAssist.SendAfter do
  @moduledoc """
  Simple assistance wrapper for SendAfter calls to record the TimerRef's.

  Idea is then to use this data to display an internal page, in order to verify whether
  our GenServers run as intended.
  """

  @doc """
  Wrap Process.send_after/4 to ensure that we can record timer data.
  """
  def send_after(timer_name, pid, w, delay, opts \\ []) do
    timer_ref = Process.send_after(pid, w, delay, opts)

    # Insert to ETS
    :ets.insert(:boilerplate_assist_sendafter, {timer_name, {pid, timer_ref}})

    # Clean it up, to get rid of expired timers
    cleanup_ets()

    timer_ref
  end

  @doc """
  Return the timers registered with this Assist module.

  Calls cleanup_ets() before.
  """
  def get_timer_data() do
    cleanup_ets()

    ets_data = :ets.tab2list(:boilerplate_assist_sendafter)

    for {k, {pid, timer_ref}} <- ets_data do
      time_left = :erlang.read_timer(timer_ref)
      %{timer_name: k, pid: pid, timer_ref: timer_ref, time_left: time_left}
    end
  end

  defp cleanup_ets() do
    ets_data = :ets.tab2list(:boilerplate_assist_sendafter)

    for {k, {_pid, timer_ref}} <- ets_data do
      if :erlang.read_timer(timer_ref) == false do
        # Timer expired
        :ets.delete(:boilerplate_assist_sendafter, k)
      end
    end
  end
end
