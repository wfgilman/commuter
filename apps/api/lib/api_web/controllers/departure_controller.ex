defmodule ApiWeb.DepartureController do
  use ApiWeb, :controller

  def index(conn, %{"orig" => orig, "dest" => dest} = params) do
    case Core.Departure.get(orig, dest, to_int(params["count"])) do
      [] ->
        conn
        |> put_status(200)
        |> put_view(ApiWeb.DepartureView)
        |> render("index.json", data: Core.Station.get([orig, dest]), orig: orig, dest: dest)

      departs ->
        conn
        |> put_status(200)
        |> put_view(ApiWeb.DepartureView)
        |> render("index.json", data: departs)
    end
  end

  def index(conn, _params) do
    conn
    |> put_status(400)
    |> put_view(ApiWeb.ErrorView)
    |> render("query_params.json")
  end

  defp to_int(nil), do: 10
  defp to_int(val), do: String.to_integer(val)
end
