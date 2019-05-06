defmodule ApiWeb.Router do
  use ApiWeb, :router
  import Api.RateLimit

  pipeline :api do
    plug :accepts, ["json"]
    plug :rate_limit, max_requests: 30, interval_seconds: 60
  end

  scope "/api/v1", ApiWeb do
    pipe_through :api

    get "/stations", StationController, :index
    get "/departures", DepartureController, :index
    resources "/notifications", NotificationController, [:create, :index, :delete]
    post "/notifications/action", NotificationActionController, :create
    get "/eta", EtaController, :index
    get "/advisories", AdvisoryController, :index
    get "/commutes", CommuteController, :index
  end
end
