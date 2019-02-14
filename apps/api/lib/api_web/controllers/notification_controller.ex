defmodule ApiWeb.NotificationController do
  use ApiWeb, :controller
  require Logger

  def create(conn, %{
        "device_id" => device_id,
        "trip_id" => trip_id,
        "station_id" => station_id,
        "remove" => true
      }) do
    _ = Core.Notification.delete(device_id, trip_id, station_id)
    send_resp(conn, 204, "")
  end

  def create(conn, %{"device_id" => device_id, "trip_id" => trip_id, "station_id" => station_id} = params) do
    case Core.Notification.store(device_id, trip_id, station_id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, changeset} ->
        Logger.info("POST /notifications: #{inspect(params)} #{inspect(changeset)}")
        conn
        |> put_status(400)
        |> put_view(ApiWeb.ErrorView)
        |> render("changeset.json", data: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    _ = Core.Notification.delete(id)
    send_resp(conn, 204, "")
  end

  def index(conn, %{"device_id" => device_id}) do
    muted = Core.Notification.is_muted?(device_id)
    notifs = Core.Notification.get(device_id)

    conn
    |> put_status(200)
    |> put_view(ApiWeb.NotificationView)
    |> render("index.json", data: notifs, muted: muted)
  end
end
