defmodule Core.Sched do
  import Ecto.Query

  def get(orig, dest, count) do
    all_trips =
      orig
      |> departing()
      |> chunk_into_trips()

    direct_trips =
      all_trips
      |> Enum.map(fn stops ->
        Enum.filter(stops, &(&1.station == orig or &1.station == dest))
      end)
      |> Enum.filter(fn stops -> Enum.count(stops) == 2 end)
      |> Enum.map(fn stops ->
        os = Enum.at(stops, 0)
        ds = Enum.at(stops, 1)

        %{
          trip_id: os.trip_id,
          orig_station: os.station,
          dest_station: ds.station,
          etd: os.etd,
          eta: ds.eta,
          etd_day_offset: os.etd_day_offset,
          eta_day_offset: ds.eta_day_offset,
          duration_min: duration_min(os.etd, ds.eta, os.etd_day_offset, ds.eta_day_offset),
          stops: ds.sequence - os.sequence,
          prior_stops: os.sequence,
          final_dest_code: os.final_dest_code,
          headsign: os.headsign,
          route_hex_color: os.route_hex_color,
          route_code: os.route_code,
          transfer_route_hex_color: nil,
          transfer_station: nil,
          transfer_wait_min: nil
        }
      end)

    transfer_trips =
      all_trips
      |> Enum.reject(fn stops ->
        Enum.any?(stops, fn %{trip_id: trip_id} ->
          direct_trips
          |> Enum.map(& &1.trip_id)
          |> Enum.member?(trip_id)
        end)
      end)

    transfer_from_routes =
      transfer_trips
      |> Enum.map(fn stops ->
        Enum.map(stops, &(&1.route_code))
      end)
      |> List.flatten()
      |> Enum.uniq()

    connecting_arriving_trips =
      dest
      |> arriving()
      |> chunk_into_trips()
      |> Enum.reject(fn stops ->
        Enum.any?(stops, fn %{trip_id: trip_id} ->
          direct_trips
          |> Enum.map(& &1.trip_id)
          |> Enum.member?(trip_id)
        end)
      end)
      |> Enum.map(fn stops ->
        Enum.filter(
          stops,
          &(matching_transfer_station?(&1, transfer_trips) or &1.station == dest)
        )
      end)
      # |> Enum.map(fn stops ->
      #   stops
      #   |> Enum.map(fn stop ->
      #     stop
      #     |> Map.put(:t, matching_transfer_station?(stop, transfer_trips))
      #     |> Map.put(:tt, matching_timed_transfer_station?(stop, transfer_trips, transfer_from_routes))
      #     |> Map.put(:d, stop.station == dest)
      #   end)
      #   |> Enum.filter(fn stop ->
      #     stop.d == true or stop.t == true or stop.tt == true
      #   end)
      # end)
      |> Enum.filter(fn stops -> Enum.count(stops) > 1 end)
      |> Enum.map(fn stops -> Enum.reverse(stops) end)
      |> Enum.map(fn stops -> Enum.take(stops, 2) end)
      |> Enum.map(fn stops -> Enum.reverse(stops) end)

    connecting_transfer_trips =
      transfer_trips
      |> Enum.map(fn stops ->
        Enum.filter(
          stops,
          &(matching_transfer_station?(&1, connecting_arriving_trips) or &1.station == orig)
        )
      end)
      |> Enum.filter(fn stops -> Enum.count(stops) == 2 end)
      |> Enum.map(fn stops ->
        os = Enum.at(stops, 0)
        ts = Enum.at(stops, 1)

        %{
          trip_id: os.trip_id,
          orig_station: os.station,
          transfer_station: ts.station,
          etd: os.etd,
          eta: ts.eta,
          etd_day_offset: os.etd_day_offset,
          eta_day_offset: ts.eta_day_offset,
          duration_min: duration_min(os.etd, ts.eta, os.etd_day_offset, ts.eta_day_offset),
          stops: ts.sequence - os.sequence,
          prior_stops: os.sequence,
          final_dest_code: os.final_dest_code,
          headsign: os.headsign,
          route_hex_color: os.route_hex_color,
          route_code: os.route_code
        }
      end)

    connecting_arriving_trips =
      connecting_arriving_trips
      |> Enum.map(fn stops ->
        ts = Enum.at(stops, 0)
        ds = Enum.at(stops, 1)

        %{
          trip_id: ts.trip_id,
          transfer_station: ts.station,
          dest_station: ds.station,
          etd: ts.etd,
          eta: ds.eta,
          etd_day_offset: ts.etd_day_offset,
          eta_day_offset: ds.eta_day_offset,
          duration_min: duration_min(ts.etd, ds.eta, ts.etd_day_offset, ds.eta_day_offset),
          stops: ds.sequence - ts.sequence,
          prior_stops: ts.sequence,
          final_dest_code: ts.final_dest_code,
          headsign: ts.headsign,
          route_hex_color: ts.route_hex_color,
          route_code: ts.route_code
        }
      end)
      |> Enum.sort_by(&{&1.etd_day_offset, Time.to_erl(&1.etd)})

    transfers =
      connecting_transfer_trips
      |> Enum.map(fn from_trip ->
        to_trip =
          Enum.find(connecting_arriving_trips, fn trip ->
            transfer_possible?(from_trip, trip)
          end)

        unless is_nil(to_trip) do
          transfer_delay =
            transfer_delay_min(
              from_trip.eta,
              to_trip.etd,
              to_trip.etd_day_offset,
              from_trip.eta_day_offset
            )

          from_trip
          |> Map.put(:std, from_trip.etd)
          |> Map.put(:eta, to_trip.eta)
          |> Map.put(
            :duration_min,
            round(from_trip.duration_min + transfer_delay + to_trip.duration_min)
          )
          |> Map.put(:stops, from_trip.stops + to_trip.stops)
          |> Map.put(:dest_station, to_trip.dest_station)
          |> Map.put(:transfer_route_hex_color, to_trip.route_hex_color)
          |> Map.put(:transfer_wait_min, transfer_delay)
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    direct_trips
    |> Kernel.++(transfers)
    |> Enum.sort_by(&{&1.etd_day_offset, Time.to_erl(&1.etd)})
    |> Enum.reduce([], fn
      trip, [] ->
        [trip]

      trip, [prior_trip | t] = acc ->
        if arrives_before?(trip, prior_trip) do
          [trip | t]
        else
          [trip | acc]
        end
    end)
    |> Enum.reverse()
    |> Enum.take(count)
  end

  defp matching_transfer_station?(stop, transfer_trips) do
    Enum.any?(transfer_trips, fn transfer_stops ->
      Enum.any?(transfer_stops, fn transfer_stop ->
        stop.station == transfer_stop.station
        and stop.transfer_station == true
      end)
    end)
  end

  defp matching_timed_transfer_station?(stop, transfer_trips, transfer_from_routes) do
    Enum.any?(transfer_trips, fn transfer_stops ->
      Enum.any?(transfer_stops, fn transfer_stop ->
        stop.station == transfer_stop.station
        and stop.timed_transfer_station == true
        and stop.timed_transfer_to_route_code in transfer_from_routes
      end)
    end)
  end

  # B connects to A sequentially.
  defp transfer_possible?(trip_a, trip_b) do
    cond do
      trip_a.eta_day_offset == trip_b.etd_day_offset and
          Time.compare(trip_b.etd, trip_a.eta) == :gt ->
        true

      trip_a.eta_day_offset == 0 and trip_b.etd_day_offset == 1 and
          Time.compare(trip_b.etd, trip_a.eta) == :lt ->
        true

      true ->
        false
    end
  end

  defp arrives_before?(trip_a, trip_b) do
    cond do
      trip_a.eta_day_offset == trip_b.eta_day_offset and
          Time.compare(trip_a.eta, trip_b.eta) == :lt ->
        true

      trip_a.eta_day_offset == 0 and trip_b.eta_day_offset == 1 and
          Time.compare(trip_a.eta, trip_b.eta) == :gt ->
        true

      true ->
        false
    end
  end

  defp chunk_into_trips(scheds) do
    chunk_fn = fn
      stop, [] ->
        {:cont, [stop]}

      %{trip_id: trip_id} = stop, [%{trip_id: prior_trip_id} | _] = acc ->
        if trip_id == prior_trip_id do
          {:cont, [stop | acc]}
        else
          {:cont, Enum.reverse(acc), [stop]}
        end
    end

    after_fn = fn
      [] ->
        {:cont, []}

      acc ->
        {:cont, Enum.reverse(acc), []}
    end

    Enum.chunk_while(scheds, [], chunk_fn, after_fn)
  end

  def departing(orig) do
    from(s in Db.Model.Schedule,
      join: t in assoc(s, :trip),
      join: r in assoc(t, :route),
      join: st in assoc(s, :station),
      join: tls in assoc(t, :trip_last_station),
      join: fst in assoc(tls, :station),
      join: dt in subquery(departing_trips(orig)),
      on: s.trip_id == dt.trip_id and s.sequence >= dt.sequence,
      left_join: tt in subquery(timed_transfer()),
      on:
        s.station_id == tt.station_id and r.id == tt.from_route_id and
          r.direction == tt.from_route_direction,
      left_join: x in Db.Model.Transfer,
      on: s.station_id == x.station_id,
      order_by: [s.trip_id, s.departure_day_offset, s.departure_time],
      distinct: true,
      select: %{
        trip_id: s.trip_id,
        etd: s.departure_time,
        eta: s.arrival_time,
        etd_day_offset: s.departure_day_offset,
        eta_day_offset: s.arrival_day_offset,
        station: st.code,
        sequence: s.sequence,
        headsign: s.headsign,
        final_dest_code: fst.code,
        route_hex_color: r.color_hex_code,
        route_direction: r.direction,
        route_code: r.code,
        timed_transfer_station: not is_nil(tt.id),
        timed_transfer_to_route_code: tt.to_route_code,
        transfer_station: not is_nil(x.id)
      }
    )
    |> Db.Repo.all()
  end

  def arriving(dest) do
    from(s in Db.Model.Schedule,
      join: t in assoc(s, :trip),
      join: r in assoc(t, :route),
      join: st in assoc(s, :station),
      join: tls in assoc(t, :trip_last_station),
      join: fst in assoc(tls, :station),
      join: at in subquery(arriving_trips(dest)),
      on: s.trip_id == at.trip_id and s.sequence <= at.sequence,
      left_join: tt in subquery(timed_transfer()),
      on:
        s.station_id == tt.station_id and r.id == tt.from_route_id and
          r.direction == tt.from_route_direction,
      left_join: x in Db.Model.Transfer,
      on: s.station_id == x.station_id,
      order_by: [s.trip_id, s.arrival_day_offset, s.arrival_time],
      distinct: true,
      select: %{
        trip_id: s.trip_id,
        etd: s.departure_time,
        eta: s.arrival_time,
        etd_day_offset: s.departure_day_offset,
        eta_day_offset: s.arrival_day_offset,
        station: st.code,
        sequence: s.sequence,
        headsign: s.headsign,
        final_dest_code: fst.code,
        route_hex_color: r.color_hex_code,
        route_direction: r.direction,
        route_code: r.code,
        timed_transfer_station: not is_nil(tt.id),
        timed_transfer_to_route_code: tt.to_route_code,
        transfer_station: not is_nil(x.id)
      }
    )
    |> Db.Repo.all()
  end

  def departing_trips(orig) do
    from(s in Db.Model.Schedule,
      join: t in assoc(s, :trip),
      join: os in assoc(s, :station),
      where: t.service_id in ^Enum.map(Core.Service.current_services(), & &1.id),
      where: s.departure_time >= ^Shared.Utils.now(),
      where: os.code == ^orig,
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence
      }
    )
  end

  def arriving_trips(dest) do
    from(s in Db.Model.Schedule,
      join: t in assoc(s, :trip),
      join: ds in assoc(s, :station),
      where: t.service_id in ^Enum.map(Core.Service.current_services(), & &1.id),
      # where: s.arrival_time >= ^Shared.Utils.now(),
      where: ds.code == ^dest,
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence
      }
    )
  end

  defp timed_transfer do
    from(t in Db.Model.Transfer,
      join: fr in assoc(t, :from_route),
      join: tr in assoc(t, :to_route),
      select: %{
        id: t.id,
        station_id: t.station_id,
        from_route_id: t.from_route_id,
        from_route_code: fr.code,
        from_route_direction: fr.direction,
        to_route_id: t.to_route_id,
        to_route_code: tr.code,
        to_route_direction: tr.direction,
        transfer_time_sec: t.transfer_time_sec
      }
    )
  end

  def transfer_delay_min(eta, etd, 1, 0) do
    round(Time.diff(etd, eta) / 60) + 24 * 60
  end

  def transfer_delay_min(eta, etd, _, _) do
    round(Time.diff(etd, eta) / 60)
  end

  def duration_min(etd, eta, 0, 1) do
    round(Time.diff(eta, etd) / 60) + 24 * 60
  end

  def duration_min(etd, eta, _, _) do
    round(Time.diff(eta, etd) / 60)
  end
end
