defmodule Db.Model.Service do
  use Ecto.Schema

  schema "service" do
    field(:code, :string)
    field(:name, :string)
    timestamps()
  end
end
