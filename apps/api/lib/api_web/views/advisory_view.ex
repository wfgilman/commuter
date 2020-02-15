defmodule ApiWeb.AdvisoryView do
  use ApiWeb, :view

  def render("index.json", %{data: advisory}) do
    Map.from_struct(advisory)
  end
end
