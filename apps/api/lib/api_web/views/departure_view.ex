defmodule ApiWeb.DepartureView do
  use ApiWeb, :view

  def render("index.json", %{departures: departs, orig: orig, dest: dest, as_of: as_of}) do
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
      as_of: as_of,
      includes_real_time: check_real_time(departs),
      departures: Enum.map(departs, &depart_json/1)
    }
  end

  defp check_real_time(departures) do
    number_rt =
      Enum.reduce(departures, 0, fn %{real_time: rt}, acc ->
        if rt == true, do: acc + 1, else: acc
      end)

    if number_rt > 0, do: true, else: false
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
      :headsign_code,
      :stops,
      :prior_stops,
      :route_hex_color,
      :notify,
      :real_time
    ])
  end
end
