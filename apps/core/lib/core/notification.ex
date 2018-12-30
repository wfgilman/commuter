defmodule Core.Notification do
  import Ecto.Query

  @required_params [:device_id, :trip_id]

  @doc """
  Stores a notification.
  """
  @spec store(String.t(), integer) ::
          {:ok, Db.Model.TripNotification.t()} | {:error, Ecto.Changeset.t()}
  def store(device_id, trip_id) do
    params = %{
      device_id: device_id,
      trip_id: trip_id
    }

    %Db.Model.TripNotification{}
    |> Ecto.Changeset.cast(params, @required_params)
    |> Ecto.Changeset.validate_required(@required_params)
    |> Ecto.Changeset.assoc_constraint(:trip)
    |> Db.Repo.insert(on_conflict: :replace_all, conflict_target: @required_params)
  end

  @doc """
  Deletes a notification.
  """
  @spec delete(String.t(), integer) :: :ok
  def delete(device_id, trip_id) do
    from(n in Db.Model.TripNotification,
      where: n.device_id == ^device_id,
      where: n.trip_id == ^trip_id
    )
    |> Db.Repo.delete_all()

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
end
