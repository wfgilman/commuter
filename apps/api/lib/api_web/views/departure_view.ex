defmodule ApiWeb.DepartureView do
  use ApiWeb, :view

  def render("index.json", %{departures: departs, orig: orig, dest: dest}) do
    %{
      orig: %{
        id: orig.id,
        code: orig.code,
        name: orig.name
      },
      dest: %{
        id: dest.id,
        code: dest.code,
        name: dest.name
      },
      departures: Enum.map(departs, &depart_json/1)
    }
  end

  defp depart_json(departure) do
    Map.take(departure, [
      :trip_id,
      :etd,
      :etd_min,
      :std,
      :eta,
      :duration_min,
      :delay_min,
      :length,
      :final_dest_code,
      :headsign,
      :stops,
      :prior_stops,
      :route_hex_color,
      :notify,
      :real_time
    ])
  end
end
