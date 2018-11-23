defmodule Db.Model.Trip do
  use Ecto.Schema

  schema "trip" do
    field(:code, :string)
    field(:headsign, :string)
    field(:direction, :string)
    belongs_to(:route, Db.Model.Route)
    belongs_to(:service, Db.Model.Service)
    timestamps()
  end
end
