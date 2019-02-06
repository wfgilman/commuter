defmodule ApiWeb.AdvisoryController do
  use ApiWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(200)
    |> put_view(ApiWeb.AdvisoryView)
    |> render("index.json", data: Core.ServiceAdvisory.get())
  end
end
