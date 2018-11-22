defmodule Db.Model.Route do
  use Ecto.Schema
  
  schema "route" do
    field :code, :string
    field :name, :string
    field :url, :string
    field :color, :string
    field :color_hex_code, :string
    belongs_to :agency, Db.Model.Agency
  end
end
