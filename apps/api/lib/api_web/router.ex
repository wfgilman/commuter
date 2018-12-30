defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", ApiWeb do
    pipe_through :api

    get "/stations", StationController, :index
    get "/departures", DepartureController, :index
    resources "/notifications", NotificationController, [:create, :index]
  end
end
