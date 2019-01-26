defmodule Core.Commute do
  import Ecto.Query

  defstruct [:route_code, :route_name, :direction, :orig_station_code, :dest_station_code]

  @type t :: %__MODULE__{
          route_code: String.t(),
          route_name: String.t(),
          direction: String.t(),
          orig_station_code: String.t(),
          dest_station_code: String.t()
        }

  @doc """
  Get route and direction based on start and end station. Excludes transfers.
  """
  @spec get(String.t(), String.t()) :: [Core.Commute.t()]
  def get(orig_station, dest_station) do
    from(t in Db.Model.Trip,
      join: r in assoc(t, :route),
      join: ss in subquery(trips_through_station(orig_station)),
      on: ss.trip_id == t.id,
      join: es in subquery(trips_through_station(dest_station)),
      on: es.trip_id == t.id,
      where: ss.sequence < es.sequence,
      distinct: true,
      select: %{
        route_code: r.code,
        route_name: r.name,
        direction: t.direction,
        orig_station_code: ^orig_station,
        dest_station_code: ^dest_station
      }
    )
    |> Db.Repo.all()
    |> Enum.map(&struct(__MODULE__, &1))
  end

  defp trips_through_station(station) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      where: st.code == ^station,
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence
      }
    )
  end
end
