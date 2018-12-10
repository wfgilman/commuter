defmodule ApiWeb.DepartureView do
  use ApiWeb, :view

  def render("index.json", %{data: [%Core.Departure{} = d | _] = departs}) do
    %{
      orig: %{
        code: d.orig_code,
        name: d.orig_name
      },
      dest: %{
        code: d.dest_code,
        name: d.dest_name
      },
      departures: Enum.map(departs, &depart_json/1)
    }
  end

  def render("index.json", %{data: stations, orig: orig, dest: dest}) do
    orig = Enum.find(stations, &(&1.code == orig))
    dest = Enum.find(stations, &(&1.code == dest))

    %{
      orig: %{
        code: orig.code,
        name: orig.name
      },
      dest: %{
        code: dest.code,
        name: dest.name
      },
      departures: []
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
      :route_hex_color
    ])
  end
end
