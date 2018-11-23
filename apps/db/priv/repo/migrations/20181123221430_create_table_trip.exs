defmodule Db.Repo.Migrations.CreateTableTrip do
  use Ecto.Migration

  def change do
    create table("trip") do
      add :code, :string
      add :headsign, :string
      add :direction, :string
      add :route_id, references(:route)
      add :service_id, references(:service)

      timestamps()
    end

    create unique_index("trip", [:code, :service_id])
    create index("trip", [:route_id])
    create index("trip", [:service_id])
  end
end
