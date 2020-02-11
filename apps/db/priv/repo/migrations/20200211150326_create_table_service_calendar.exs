defmodule Db.Repo.Migrations.CreateTableServiceCalendar do
  use Ecto.Migration

  def change do
    create table("service_calendar") do
      add :mon, :boolean
      add :tue, :boolean
      add :wed, :boolean
      add :thu, :boolean
      add :fri, :boolean
      add :sat, :boolean
      add :sun, :boolean
      add :date_effective, :date
      add :service_id, references(:service, on_delete: :delete_all)

      timestamps()
    end

  create unique_index("service_calendar", [:service_id, :date_effective])
  end
end
