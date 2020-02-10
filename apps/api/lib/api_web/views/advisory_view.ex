defmodule ApiWeb.AdvisoryView do
  use ApiWeb, :view

  def render("index.json", %{data: advisory}) do
    # Map.from_struct(advisory)
    %{
      count: 1,
      advisory: "Feb 10th schedule changes have not been incorporated yet. Departures may not be accurate."
    }
  end
end
