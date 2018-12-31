defmodule ApiWeb.NotificationActionController do
  use ApiWeb, :controller

  def create(conn, %{"device_id" => device_id, "mute" => true}) do
    case Core.Notification.mute_device(device_id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> put_view(ApiWeb.ErrorView)
        |> render("changeset.json", data: changeset)
    end
  end

  def create(conn, %{"device_id" => device_id, "mute" => false}) do
    _ = Core.Notification.unmute_device(device_id)
    send_resp(conn, 204, "")
  end
end
