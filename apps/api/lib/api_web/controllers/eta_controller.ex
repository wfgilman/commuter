defmodule ApiWeb.EtaController do
  use ApiWeb, :controller

  def index(conn, %{"lat" => lat, "lon" => lon, "orig" => orig, "dest" => dest}) do
    with commutes when commutes != [] <- Core.Commute.get(orig, dest),
         commute = Enum.at(commutes, 0),
         lat = String.to_float(lat),
         lon = String.to_float(lon),
         eta when not is_nil(eta) <- Core.ETA.calculate(lat, lon, commute) do
      conn
      |> put_status(200)
      |> put_view(ApiWeb.ETAView)
      |> render("index.json", data: eta)
    else
      [] ->
        conn
        |> put_status(404)
        |> put_view(ApiWeb.ErrorView)
        |> render("404.json", message: "We don't yet support your commute.")

      nil ->
        conn
        |> put_status(404)
        |> put_view(ApiWeb.ErrorView)
        |> render("404.json", message: "We couldn't find your location.")
    end
  end
end
