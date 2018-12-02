defmodule ApiWeb.DepartureController do
  use ApiWeb, :controller

  def index(conn, %{"orig" => orig, "dest" => dest, "direction" => dir} = params) do
    conn
    |> put_status(200)
    |> put_view(ApiWeb.DepartureView)
    |> render("index.json", data: Core.Departure.get(orig, dest, dir, count(params["count"])))
  end

  defp count(nil), do: nil
  defp count(val), do: String.to_integer(val)
end
