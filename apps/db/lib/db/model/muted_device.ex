defmodule Db.Model.MutedDevice do
  use Ecto.Schema

  schema "muted_device" do
    field(:device_id, :string)
    timestamps()
  end
end
