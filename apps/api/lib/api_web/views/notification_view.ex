defmodule ApiWeb.NotificationView do
  use ApiWeb, :view

  def render("index.json", %{data: notifs}) do
    %{
      object: "notification",
      data: Enum.map(notifs, &notif_json/1)
    }
  end

  defp notif_json(notif) do
    %{
      id: notif.id,
      descrip: make_descrip(notif)
    }
  end

  defp make_descrip(notif) do
    time = Timex.format!(notif.departure_time, "{h12}:{m} {am}")
    svc = "#{notif.service_name}s"
    "#{svc} departing #{notif.orig_station_code} at #{time}"
  end
end
