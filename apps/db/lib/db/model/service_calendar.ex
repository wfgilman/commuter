defmodule Db.Model.ServiceCalendar do
  use Ecto.Schema

  schema "service_calendar" do
    field(:mon, :boolean)
    field(:tue, :boolean)
    field(:wed, :boolean)
    field(:thu, :boolean)
    field(:fri, :boolean)
    field(:sat, :boolean)
    field(:sun, :boolean)
    field(:date_effective, :date)
    belongs_to(:service, Db.Model.Service)
    timestamps()
  end
end
