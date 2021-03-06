defmodule ApiWeb.DepartureController do
  use ApiWeb, :controller

  def index(conn, %{"orig" => orig, "dest" => dest} = params) do
    stations = Core.Station.get([orig, dest])
    orig_station = Enum.find(stations, &(&1.code == orig))
    dest_station = Enum.find(stations, &(&1.code == dest))

    {departs, as_of} =
      Core.Departure.get(
        orig,
        dest,
        to_int(params["count"]),
        to_bool(params["real_time"]),
        params["device_id"]
      )

    conn
    |> put_status(200)
    |> put_view(ApiWeb.DepartureView)
    |> render("index.json",
      departures: departs,
      orig: orig_station,
      dest: dest_station,
      as_of: as_of
    )
  end

  def index(conn, _params) do
    conn
    |> put_status(400)
    |> put_view(ApiWeb.ErrorView)
    |> render("query_params.json")
  end

  defp to_int(nil), do: 10
  defp to_int(val), do: String.to_integer(val)

  defp to_bool("true"), do: true
  defp to_bool("false"), do: false
end
