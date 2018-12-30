defmodule ApiWeb.NotificationController do
  use ApiWeb, :controller

  def create(conn, %{"device_id" => device_id, "trip_id" => trip_id, "delete" => true}) do
    Core.Notification.delete(device_id, trip_id)
    send_resp(conn, 204, "")
  end

  def create(conn, %{"device_id" => device_id, "trip_id" => trip_id}) do
    case Core.Notification.store(device_id, trip_id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> put_view(ApiWeb.ErrorView)
        |> render("changeset.json", data: changeset)
    end
  end
end
