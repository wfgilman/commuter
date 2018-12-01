defmodule Db.StationName do
  @behaviour Ecto.Type

  def type, do: :binary

  def cast(name) when is_binary(name) do
    {:ok, name}
  end

  def cast(_), do: :error

  def load(name) do
    {:ok, String.trim_trailing(name, " BART Station")}
  end

  def dump(name) do
    {:ok, name}
  end
end
