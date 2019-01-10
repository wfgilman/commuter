defmodule Core.Notification do
  import Ecto.Query

  @required_params [:device_id, :trip_id, :station_id]

  @doc """
  Stores a notification.
  """
  @spec store(String.t(), integer, integer) ::
          {:ok, Db.Model.TripNotification.t()} | {:error, Ecto.Changeset.t()}
  def store(device_id, trip_id, station_id) do
    params = %{
      device_id: device_id,
      trip_id: trip_id,
      station_id: station_id
    }

    %Db.Model.TripNotification{}
    |> Ecto.Changeset.cast(params, @required_params)
    |> Ecto.Changeset.validate_required(@required_params)
    |> Ecto.Changeset.assoc_constraint(:trip)
    |> Ecto.Changeset.assoc_constraint(:station)
    |> Db.Repo.insert(on_conflict: :replace_all, conflict_target: @required_params)
  end

  @doc """
  Deletes a notification by id.
  """
  @spec delete(integer) :: :ok
  def delete(id) do
    from(n in Db.Model.TripNotification, where: n.id == ^id)
    |> Db.Repo.delete_all()

    :ok
  end

  @doc """
  Deletes a notification by device, trip and station.
  """
  @spec delete(String.t(), integer, integer) :: :ok
  def delete(device_id, trip_id, station_id) do
    from(n in Db.Model.TripNotification,
      where: n.device_id == ^device_id,
      where: n.trip_id == ^trip_id,
      where: n.station_id == ^station_id
    )
    |> Db.Repo.delete_all()

    :ok
  end

  @doc """
  Deletes device.
  """
  @spec delete_device_id(String.t()) :: :ok
  def delete_device_id(device_id) do
    from(n in Db.Model.TripNotification,
      where: n.device_id == ^device_id
    )
    |> Db.Repo.delete_all()

    :ok = unmute_device(device_id)

    :ok
  end

  @doc """
  Get all trip_ids for a device.
  """
  @spec get_trip_ids(String.t() | nil) :: [integer]
  def get_trip_ids(nil), do: []

  def get_trip_ids(device_id) do
    from(n in Db.Model.TripNotification,
      where: n.device_id == ^device_id,
      select: n.trip_id
    )
    |> Db.Repo.all()
  end

  @doc """
  Get all trip info associated with a device.
  """
  @spec get(String.t()) :: [map]
  def get(device_id) do
    from(s in Db.Model.Schedule,
      join: tn in Db.Model.TripNotification,
      on: tn.trip_id == s.trip_id and tn.station_id == s.station_id,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: svc in assoc(t, :service),
      where: tn.device_id == ^device_id,
      select: %{
        id: tn.id,
        trip_id: t.id,
        orig_station_code: st.code,
        departure_time: s.departure_time,
        service_name: svc.name
      }
    )
    |> Db.Repo.all()
  end

  @doc """
  Checks if device id is muted.
  """
  @spec is_muted?(String.t()) :: boolean
  def is_muted?(device_id) do
    from(md in Db.Model.MutedDevice,
      where: md.device_id == ^device_id
    )
    |> Db.Repo.exists?()
  end

  @doc """
  Added device id to table of devices to ignore.
  """
  @spec mute_device(String.t()) :: {:ok, Db.Model.MutedDevice.t()} | {:error, Ecto.Changeset.t()}
  def mute_device(device_id) do
    %Db.Model.MutedDevice{}
    |> Ecto.Changeset.cast(%{device_id: device_id}, [:device_id])
    |> Ecto.Changeset.validate_required([:device_id])
    |> Db.Repo.insert(on_conflict: :replace_all, conflict_target: :device_id)
  end

  @doc """
  Deletes device id from table of devices to ignore.
  """
  @spec unmute_device(String.t()) :: :ok
  def unmute_device(device_id) do
    from(md in Db.Model.MutedDevice,
      where: md.device_id == ^device_id
    )
    |> Db.Repo.delete_all()

    :ok
  end

  @doc """
  Get list of upcoming depatures to notify devices.
  """
  @spec poll(integer) :: list
  def poll(offset_min) do
    from(tn in Db.Model.TripNotification,
      join: s in Db.Model.Schedule,
      on: tn.trip_id == s.trip_id and tn.station_id == s.station_id,
      join: st in assoc(tn, :station),
      where: s.departure_time >= ^current_time(offset_min - 1),
      where: s.departure_time <= ^current_time(offset_min),
      select: %{
        station_code: st.code,
        depart_time: s.departure_time,
        device_id: tn.device_id
      }
    )
    |> Db.Repo.all()
  end

  defp current_time(offset_min) do
    Time.utc_now()
    |> Time.add(-(8 * 60 * 60), :second)
    |> Time.add(offset_min * 60, :second)
    |> Time.truncate(:second)
  end
end
