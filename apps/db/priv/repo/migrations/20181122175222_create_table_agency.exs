defmodule Db.Repo.Migrations.CreateTableAgency do
  use Ecto.Migration

  def change do
    create table("agency") do
      add :agency_id, :string
      add :agency_name, :string
      add :agency_url, :string
      add :agency_timezone, :string
      add :agency_lang, :string

      timestamps()
    end

    create unique_index("agency", [:agency_id])
  end
end
