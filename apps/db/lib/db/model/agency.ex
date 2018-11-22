defmodule Db.Model.Agency do
  use Ecto.Schema
  schema "agency" do
    field :code, :string
    field :name, :string
    field :url, :string
    field :timezone, :string
    field :lang, :string
  end
end
