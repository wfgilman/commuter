defmodule Db.Repo.Migrations.CreateTableService do
  use Ecto.Migration

  def change do
    create table("service") do
      add :code, :string
      add :name, :string

      timestamps()
    end

    create unique_index("service", [:code])
  end
end
