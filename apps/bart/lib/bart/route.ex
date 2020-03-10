defmodule Bart.Route do
  defstruct name: nil,
            abbr: nil,
            code: nil,
            origin: nil,
            destination: nil,
            direction: nil,
            hex_color: nil,
            color: nil,
            num_stns: nil,
            station_seq: []

  @type t :: %__MODULE__{
          name: String.t(),
          abbr: String.t(),
          code: String.t(),
          origin: String.t(),
          destination: String.t(),
          direction: String.t(),
          hex_color: String.t(),
          color: String.t(),
          num_stns: integer,
          station_seq: [Bart.Route.StationSequence.t()]
        }

  defmodule StationSequence do
    defstruct code: nil, sequence: nil
    @type t :: %__MODULE__{code: Stringt.t(), sequence: integer}
  end

  @endpoint "route"

  require Logger

  @doc """
  Gets the information about a route, including the stations and their sequences.
  """
  @spec get(String.t()) :: Bart.Route.t() | nil
  def get(route_id) do
    params = %{
      cmd: "routeinfo",
      route: route_id
    }

    :get
    |> Bart.make_request(@endpoint, params)
    |> handle_resp()
  end

  defp handle_resp({:error, _}), do: nil

  defp handle_resp({:ok, %{body: {:invalid, body}}}) do
    Logger.info("BART Response body: #{inspect(body)}")
    nil
  end

  defp handle_resp(
         {:ok, %{body: %{"root" => %{"routes" => %{"route" => route}}}, status_code: 200}}
       ) do
    %Bart.Route{
      name: route["name"],
      abbr: route["abbr"],
      code: route["number"],
      origin: route["origin"],
      destination: route["destination"],
      hex_color: route["hexcolor"],
      color: route["color"],
      direction: route["direction"],
      num_stns: String.to_integer(route["num_stns"]),
      station_seq: assign_station_sequence(route["config"]["station"])
    }
  end

  defp assign_station_sequence(nil), do: []

  defp assign_station_sequence(stations) do
    stations
    |> Enum.reduce(1, fn
      abbr, 1 ->
        [
          %{
            code: abbr,
            sequence: 1
          }
        ]

      abbr, [%{code: _, sequence: seq} | _] = acc ->
        [
          %{
            code: abbr,
            sequence: seq + 1
          }
          | acc
        ]
    end)
    |> Enum.map(&struct(Bart.Route.StationSequence, &1))
    |> Enum.reverse()
  end
end
