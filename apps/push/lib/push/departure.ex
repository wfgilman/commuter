defmodule Push.Departure do
  use GenServer
  require Logger

  @poll_interval_sec 60
  @depart_alert_min 10

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    poll()
    state = []
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll(@poll_interval_sec)
    notifs = Core.Notification.poll(@depart_alert_min)

    handler = fn %Pigeon.APNS.Notification{response: resp, device_token: device_id} ->
      case resp do
        :bad_device_token ->
          Logger.info("Deleting device_id: #{device_id}")
          Core.Notification.delete_device_id(device_id)

        _ ->
          :ok
      end
    end

    for notif <- notifs do
      message = get_message(notif)
      n = Pigeon.APNS.Notification.new(message, notif.device_id, "Upcoming Departure")
      Pigeon.APNS.push(n, on_response: handler)
    end

    {:noreply, state}
  end

  defp poll(sec \\ 0) do
    Process.send_after(__MODULE__, :poll, sec * 1_000)
  end

  defp get_message(%{station_code: code, depart_time: depart_time}) do
    eta_min = get_eta_min(depart_time)
    {:ok, time} = Timex.format(depart_time, "{h12}:{0m} {am}")

    "The #{time} from #{code} departs in #{eta_min} min"
  end

  defp get_eta_min(depart_time) do
    Time.utc_now()
    |> Time.add(-(8 * 60 * 60), :second)
    |> Time.truncate(:second)
    |> Time.diff(depart_time)
    |> Kernel./(60)
    |> round()
    |> abs()
  end
end
