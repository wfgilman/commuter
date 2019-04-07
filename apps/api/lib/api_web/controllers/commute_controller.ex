defmodule ApiWeb.CommuteController do
  use ApiWeb, :controller

  def index(conn, %{"orig" => orig, "dest" => dest}) do
    case Core.Commute.get(orig, dest) do
      [] ->
        conn
        |> put_status(404)
        |> put_view(ApiWeb.ErrorView)
        |> render("404.json",
          message: "Sorry, we don't yet support commutes requiring a station transfer."
        )

      _ ->
        send_resp(conn, 204, "")
    end
  end
end
