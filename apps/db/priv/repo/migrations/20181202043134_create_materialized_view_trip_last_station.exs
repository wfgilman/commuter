defmodule Db.Repo.Migrations.CreateMaterializedViewTripLastStation do
  use Ecto.Migration

  def up do
    execute """
    CREATE MATERIALIZED VIEW trip_last_station AS
    WITH trip_with_row AS (
      SELECT
          s.trip_id,
          s.sequence,
          s.station_id,
          ROW_NUMBER() OVER (PARTITION BY s.trip_id ORDER BY s.sequence DESC) AS row_num
      FROM schedule s
    )
    SELECT
        trip_id,
        station_id
    FROM trip_with_row
    WHERE row_num = 1;
    """

    execute """
    CREATE OR REPLACE FUNCTION refresh_trip_last_station()
    RETURNS trigger AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW trip_last_station;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER refresh_trip_last_station_trg
    AFTER INSERT OR UPDATE OR DELETE
    ON trip
    FOR EACH STATEMENT
    EXECUTE PROCEDURE refresh_trip_last_station();
    """
  end

  def down do
    execute """
    DROP MATERIALIZED VIEW trip_last_station;
    """

    execute """
    DROP FUNCTION refresh_trip_last_station() CASCADE;
    """
  end
end
