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

  def reset_all_notifications do
    Process.send(__MODULE__, :reset_all, [])
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
    # notifs = Core.Notification.poll(@depart_alert_min, excluded_device_ids)
    notifs = []

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
      send_notification(message, notif.device_id, handler)
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

  @impl true
  def handle_info(:reset_all, state) do
    message =
      "Just a heads up that BART has changed their schedule so we've reset all your trip notifications. Please update your favorite trips in the app!"

    device_ids = Core.Notification.all_device_ids()

    for device_id <- device_ids do
      send_notification(message, device_id, nil)
    end

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

  defp send_notification(message, device_id, handler) do
    Pigeon.APNS.Notification.new(message, device_id, "BGHFM.Commuter")
    |> Pigeon.APNS.Notification.put_sound("default")
    |> handle_response(handler)
  end

  defp handle_response(notification, nil) do
    Pigeon.APNS.push(notification)
  end

  defp handle_response(notification, handler) do
    Pigeon.APNS.push(notification, on_response: handler)
  end
end
