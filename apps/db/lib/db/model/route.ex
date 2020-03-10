defmodule Db.Model.Route do
  use Ecto.Schema

  schema "route" do
    field(:code, :string)
    field(:name, :string)
    field(:url, :string)
    field(:color, :string)
    field(:color_hex_code, :string)
    field(:direction, :string)
    belongs_to(:agency, Db.Model.Agency)
    has_many(:route_station, Db.Model.RouteStation)
    timestamps()
  end
end
