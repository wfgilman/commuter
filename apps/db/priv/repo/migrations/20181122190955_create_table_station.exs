defmodule Db.Repo.Migrations.CreateTableStation do
  use Ecto.Migration

  def change do
    create table("station") do
      add :code, :string
      add :name, :string
      add :lat, :decimal
      add :lon, :decimal
      add :url, :string

      timestamps()
    end

    create unique_index("station", [:code])
  end
end
