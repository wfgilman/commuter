defmodule Push.Departure do
  use GenServer
  require Logger
  import Shared.Utils

  @poll_interval_sec 30
  @purge_after_min 3
  @depart_alert_min 20

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    purge()
    poll()
    state = []
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll(@poll_interval_sec)
    excluded_device_ids = Enum.map(state, & &1.device_id)
    notifs = Core.Notification.poll(@depart_alert_min, excluded_device_ids)

    state =
      state ++
        Enum.map(notifs, fn notif ->
          %{device_id: notif.device_id, polled_at: Time.utc_now()}
        end)

    handler = fn %Pigeon.APNS.Notification{response: resp, device_token: device_id} ->
      case resp do
        :bad_device_token ->
          Logger.info("Deleting device_id: #{device_id}")
          Core.Notification.delete_device_id(device_id)

        resp ->
          Logger.info("Push sent with response: #{resp}")
          :ok
      end
    end

    for notif <- notifs do
      message = get_message(notif)

      Pigeon.APNS.Notification.new(message, notif.device_id, "BGHFM.Commuter")
      |> Pigeon.APNS.Notification.put_sound("default")
      |> Pigeon.APNS.push(on_response: handler)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:purge, state) do
    purge(@poll_interval_sec)

    state =
      Enum.reject(state, fn %{polled_at: time} ->
        Time.diff(Time.utc_now(), time, :second) > @purge_after_min * 60
      end)

    {:noreply, state}
  end

  defp poll(sec \\ 0) do
    Process.send_after(__MODULE__, :poll, sec * 1_000)
  end

  defp purge(sec \\ 0) do
    Process.send_after(__MODULE__, :purge, sec * 1_000)
  end

  defp get_message(%{station_code: code, depart_time: depart_time}) do
    eta_min = depart_time |> time_diff_in_min() |> abs()
    {:ok, time} = Timex.format(depart_time, "{h12}:{0m} {am}")

    "The #{time} from #{code} departs in #{eta_min} min"
  end
end
