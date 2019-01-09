defmodule Push.Departure do
  use GenServer
  require Logger

  @frequency_min 1
  @depart_alert_min 10

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    send(__MODULE__, :poll)
    state = []
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    notifs = Core.Notification.poll(@depart_alert_min)

    # Debugging code.
    if Enum.count(notifs) > 0 do
      _ = Logger.info("Found #{Enum.count(notifs)} notifcations")
    end

    for notif <- notifs do
      message = get_message(notif)
      n = Pigeon.APNS.Notification.new(message, notif.device_id, "Upcoming Departure")
      Pigeon.APNS.push(n)

      # Debugging code.
      Logger.info("Sent push notification: #{IO.inspect(n)}")
    end

    Process.send_after(__MODULE__, :poll, @frequency_min * 60 * 1_000)
    {:noreply, state}
  end

  defp get_message(%{station_code: code, depart_time: depart_time}) do
    eta_min = get_eta_min(depart_time)
    time = Timex.format(depart_time, "{h12}:{0m} {am}")

    "The #{time} leaving #{code} departs in #{eta_min} min"
  end

  defp get_eta_min(depart_time) do
    Time.utc_now()
    |> Time.add(-(8 * 60 * 60), :second)
    |> Time.truncate(:second)
    |> Time.diff(depart_time)
    |> Kernel./(60)
    |> round()
  end
end
