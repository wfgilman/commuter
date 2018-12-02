defmodule ApiWeb.StationController do
  use ApiWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(200)
    |> put_view(ApiWeb.StationView)
    |> render("index.json", data: Db.Repo.all(Db.Model.Station))
  end
end
