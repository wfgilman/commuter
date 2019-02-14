defmodule Db.Repo.Migrations.CreateTableShape do
  use Ecto.Migration

  def change do
    create table("shape") do
      add :code, :string

      timestamps()
    end

    create unique_index("shape", [:code])
  end
end
