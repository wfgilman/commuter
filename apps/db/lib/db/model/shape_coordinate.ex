defmodule Db.Model.ShapeCoordinate do
  use Ecto.Schema

  schema "shape_coordinate" do
    field(:lat, :float)
    field(:lon, :float)
    field(:sequence, :integer)
    belongs_to(:shape, Db.Model.Shape)
    timestamps()
  end
end
