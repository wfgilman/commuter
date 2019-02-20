defmodule Db.Model.ServiceException do
  use Ecto.Schema

  schema "service_exception" do
    field(:date, :date)
    belongs_to(:service, Db.Model.Service)
    timestamps()
  end
end
