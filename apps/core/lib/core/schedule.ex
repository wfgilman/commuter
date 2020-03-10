defmodule Core.Schedule do
  import Ecto.Query

  defstruct [
    :trip_id,
    :etd,
    :eta,
    :duration_min,
    :stops,
    :prior_stops,
    :final_dest_code,
    :headsign,
    :headsign_code,
    :route_hex_color,
    :service_code,
    :etd_day_offset,
    :transfer_code,
    :transfer_scheds,
    :next_transfer_sched
  ]

  @type t :: %__MODULE__{
          trip_id: integer,
          etd: Time.t(),
          eta: Time.t(),
          duration_min: integer,
          stops: integer,
          prior_stops: integer,
          final_dest_code: String.t(),
          headsign: String.t(),
          headsign_code: String.t(),
          route_hex_color: String.t(),
          service_code: String.t(),
          etd_day_offset: integer,
          transfer_code: String.t(),
          transfer_scheds: [Core.Schedule.t()],
          next_transfer_sched: Core.Schedule.t()
        }

  @doc """
  Gets schedule of all trips between two stations.
  """
  @spec get(String.t(), String.t()) :: [Core.Schedule.t()]
  def get(orig, dest) do
    direct = get_direct(orig, dest)

    # NOTE: This needs to fetch the transfer station accounting for weekend schedules.
    case Core.Commute.transfer_station_with_min_stops(orig, dest) do
      nil ->
        direct

      trans ->
        upstream =
          get_direct(orig, trans.code)
          |> Enum.reject(fn %{trip_id: trip_id} ->
            Enum.any?(direct, fn %{trip_id: direct_trip_id} ->
              trip_id == direct_trip_id
            end)
          end)

        # NOTE: should I show transfers downstream that are also direct? Would someone want to do that?
        downstream =
          get_direct(trans.code, dest)
          |> Enum.reject(fn %{trip_id: trip_id} ->
            Enum.any?(direct, fn %{trip_id: direct_trip_id} ->
              trip_id == direct_trip_id
            end)
          end)

        transfers =
          upstream
          |> Enum.sort_by(&{&1.service_code, &1.etd_day_offset, &1.etd})
          |> Enum.map(fn upstream_trip ->
            downstream_trips = find_possible_transfers(upstream_trip, downstream)

            upstream_trip
            |> Map.put(:transfer_code, trans.code)
            |> Map.put(:transfer_scheds, downstream_trips)
          end)
          |> Enum.reject(&Enum.empty?(&1.transfer_scheds))

        transfers ++ direct
    end
  end

  defp get_direct(orig_station, dest_station) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: svc in assoc(t, :service),
      join: r in assoc(t, :route),
      join: tls in assoc(t, :trip_last_station),
      join: fst in assoc(tls, :station),
      join: os in subquery(trips_through_station(orig_station)),
      on: s.trip_id == os.trip_id,
      join: ds in subquery(trips_through_station(dest_station)),
      on: s.trip_id == ds.trip_id,
      left_join: hs in Db.Model.Station,
      on: s.headsign == hs.name,
      where: st.code in [^orig_station, ^dest_station],
      where: os.sequence < ds.sequence,
      select: %{
        trip_id: s.trip_id,
        etd: over(min(s.departure_time), :trip),
        eta: over(max(s.arrival_time), :trip),
        first_stop_seq: over(min(s.sequence), :trip),
        last_stop_seq: over(max(s.sequence), :trip),
        final_dest_station_code: fst.code,
        headsign: s.headsign,
        headsign_code: hs.code,
        route_hex_color: r.color_hex_code,
        service_code: svc.code,
        etd_day_offset: s.departure_day_offset
      },
      windows: [trip: [partition_by: s.trip_id, order_by: s.sequence]],
      order_by: [s.departure_day_offset, s.departure_time]
    )
    |> Db.Repo.all()
    |> Stream.reject(&(&1.first_stop_seq == &1.last_stop_seq))
    |> Stream.map(fn depart ->
      %{
        trip_id: depart.trip_id,
        etd: depart.etd,
        eta: depart.eta,
        duration_min: round(Time.diff(depart.eta, depart.etd) / 60),
        stops: depart.last_stop_seq - depart.first_stop_seq,
        prior_stops: depart.first_stop_seq - 1,
        final_dest_code: depart.final_dest_station_code,
        headsign: depart.headsign,
        headsign_code: depart.headsign_code,
        route_hex_color: depart.route_hex_color,
        service_code: depart.service_code,
        etd_day_offset: depart.etd_day_offset
      }
    end)
    |> Enum.map(&struct(__MODULE__, &1))
  end

  def trips_through_station(station) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      where: st.code == ^station,
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence
      }
    )
  end

  # NOTE: Need to handle transfers that cross midnight.
  def find_possible_transfers(upstream_trip, downstream_trips) do
    downstream_trips
    |> Enum.sort_by(&{&1.service_code, &1.etd_day_offset, &1.etd})
    |> Enum.filter(fn downstream_trip ->
      upstream_trip.service_code == downstream_trip.service_code and
        upstream_trip.etd_day_offset == downstream_trip.etd_day_offset and
        Time.compare(downstream_trip.etd, upstream_trip.eta) in [:eq, :gt]
    end)
  end
end
