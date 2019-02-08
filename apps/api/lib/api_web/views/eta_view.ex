defmodule ApiWeb.ETAView do
  use ApiWeb, :view

  def render("index.json", %{data: eta}) do
    %{
      next_station: Map.take(eta.next_station, [:id, :code, :name]),
      next_station_eta_min: eta.next_station_eta_min,
      eta: eta.eta,
      eta_min: eta.eta_min
    }
  end
end
