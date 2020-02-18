defmodule Db.Model.Service do
  use Ecto.Schema

  schema "service" do
    field(:code, :string)
    field(:name, :string)
    has_many(:service_exception, Db.Model.ServiceException)
    has_many(:service_calendar, Db.Model.ServiceCalendar)
    timestamps()
  end
end
