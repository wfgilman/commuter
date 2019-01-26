defmodule ApiWeb.ETAView do
  use ApiWeb, :view

  def render("index.json", %{data: eta}) do
    %{
      station: Map.take(eta.station, [:id, :code, :name]),
      eta: eta.eta,
      eta_min: eta.eta_min,
      location: eta.location
    }
  end
end
