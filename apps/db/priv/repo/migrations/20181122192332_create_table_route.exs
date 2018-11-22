defmodule Db.Repo.Migrations.CreateTableRoute do
  use Ecto.Migration

  def change do
    create table("route") do
      add :code, :string
      add :color, :string
      add :name, :string
      add :url, :string
      add :color_hex_code, :string
      add :agency_id, references(:agency)
      timestamps()
    end

    create unique_index("route", [:code])
    create index("route", [:agency_id])
  end
end
