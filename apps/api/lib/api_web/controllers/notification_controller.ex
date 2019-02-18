defmodule ApiWeb.NotificationController do
  use ApiWeb, :controller

  def create(conn, %{
        "device_id" => device_id,
        "trip_id" => trip_id,
        "station_code" => station_code,
        "remove" => true
      }) do
    case Db.Repo.get_by(Db.Model.Station, code: station_code) do
      nil ->
        conn
        |> put_status(404)
        |> put_view(ApiWeb.ErrorView)
        |> render("404.json", message: "Station no longer in service.")

      station ->
        _ = Core.Notification.delete(device_id, trip_id, station.id)
        send_resp(conn, 204, "")
    end
  end

  def create(conn, %{
        "device_id" => device_id,
        "trip_id" => trip_id,
        "station_code" => station_code
      }) do
    with station when not is_nil(station) <- Db.Repo.get_by(Db.Model.Station, code: station_code),
         {:ok, _} <- Core.Notification.store(device_id, trip_id, station.id) do
      send_resp(conn, 204, "")
    else
      nil ->
        conn
        |> put_status(404)
        |> put_view(ApiWeb.ErrorView)
        |> render("404.json", message: "Station no longer in service.")

      {:error, changeset} ->
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
