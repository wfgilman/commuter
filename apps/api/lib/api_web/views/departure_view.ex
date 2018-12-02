defmodule ApiWeb.DepartureView do
  use ApiWeb, :view

  def render("index.json", %{data: departures}) do
    %{
      orig: %{
        code: Enum.at(departures, 0).orig_code,
        name: Enum.at(departures, 0).orig_name
      },
      dest: %{
        code: Enum.at(departures, 0).dest_code,
        name: Enum.at(departures, 0).dest_name
      },
      departures: Enum.map(departures, &depart_json/1)
    }
  end

  defp depart_json(departure) do
    Map.take(departure, [
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
      :prior_stops
    ])
  end
end
