defmodule Core.Station do
  import Ecto.Query

  @doc """
  Get station information.
  """
  @spec get(String.t() | [String.t()]) :: [Db.Model.Station]
  def get(station_codes) when is_list(station_codes) do
    fetch(station_codes)
  end

  def get(station_code) do
    fetch(List.wrap(station_code))
  end

  @spec all() :: [Db.Model.Station]
  def all do
    Db.Repo.all(from(s in Db.Model.Station, order_by: s.name))
  end

  defp fetch(codes) do
    Db.Repo.all(
      from(s in Db.Model.Station,
        where: s.code in ^codes,
        order_by: s.code
      )
    )
  end
end
