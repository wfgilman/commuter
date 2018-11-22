defmodule Db.Repo.Migrations.CreateTableAgency do
  use Ecto.Migration

  def change do
    create table("agency") do
      add :code, :string
      add :name, :string
      add :url, :string
      add :timezone, :string
      add :lang, :string

      timestamps()
    end

    create unique_index("agency", [:code])
  end
end
