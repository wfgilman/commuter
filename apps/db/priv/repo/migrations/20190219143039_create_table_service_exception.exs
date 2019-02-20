defmodule Db.Repo.Migrations.CreateTableServiceException do
  use Ecto.Migration

  def change do
    create table("service_exception") do
      add :date, :date
      add :service_id, references(:service, on_delete: :delete_all)

      timestamps()
    end

    create unique_index("service_exception", [:date])
  end
end
