defmodule Bart.Etd do
  defstruct date: nil, time: nil, station: [], message: nil

  @type t :: %__MODULE__{
          date: Date.t(),
          time: Time.t(),
          station: [Bart.Etd.Station],
          message: String.t()
        }

  defmodule Station do
    defstruct name: nil, abbr: nil, etd: []

    @type t :: %__MODULE__{
            name: String.t(),
            abbr: String.t(),
            etd: [Bart.Etd.Station.Etd]
          }

    defmodule Etd do
      defstruct destination: nil, abbreviation: nil, limited: nil, estimate: []

      @type t :: %__MODULE__{
              destination: String.t(),
              abbreviation: String.t(),
              limited: integer,
              estimate: [Bart.Etd.Station.Etd.Estimate]
            }

      defmodule Estimate do
        defstruct minutes: nil, platform: nil, direction: nil, length: nil, delay: nil

        @type t :: %__MODULE__{
                minutes: integer,
                platform: integer,
                direction: String.t(),
                length: integer,
                delay: integer
              }
      end
    end
  end

  @endpoint "etd"

  @doc """
  Get Real-time station departures.
  """
  @spec get(String.t(), String.t()) :: Bart.Etd.t()
  def get(station_code, direction) do
    params = %{
      cmd: "etd",
      orig: station_code,
      dir: direction_to_param(direction)
    }

    :get
    |> Bart.make_request(@endpoint, params)
    |> handle_resp()
  end

  defp direction_to_param("North"), do: "n"
  defp direction_to_param("South"), do: "s"

  defp handle_resp({:ok, %{body: %{"root" => root}, status_code: 200}}) do
    Poison.Decode.decode(root,
      as: %Bart.Etd{
        station: [
          %Bart.Etd.Station{
            etd: [%Bart.Etd.Station.Etd{estimate: [%Bart.Etd.Station.Etd.Estimate{}]}]
          }
        ]
      }
    )
    |> Map.update!(:date, fn date ->
      date
      |> Timex.parse!("{0M}/{0D}/{YYYY}")
      |> Timex.to_date()
    end)
    |> Map.update!(:time, fn <<time::bytes-size(11), _::binary>> ->
      time
      |> Timex.parse!("{h12}:{m}:{s} {am}")
      |> Timex.to_datetime()
      |> DateTime.to_time()
    end)
    |> Map.update!(:station, fn stations ->
      Enum.map(stations, &update_types/1)
    end)
  end

  defp update_types(%Bart.Etd.Station{etd: etd} = stations) do
    %{stations | etd: Enum.map(etd, &update_types/1)}
  end

  defp update_types(%Bart.Etd.Station.Etd{} = etd) do
    etd
    |> Map.update!(:limited, &String.to_integer/1)
    |> Map.update!(:estimate, fn estimates ->
      Enum.map(estimates, &update_types/1)
    end)
  end

  defp update_types(%Bart.Etd.Station.Etd.Estimate{} = estimate) do
    estimate
    |> Map.update!(:delay, &String.to_integer/1)
    |> Map.update!(:length, &String.to_integer/1)
    |> Map.update!(:minutes, fn minutes ->
      case minutes do
        "Leaving" -> 0
        _ -> String.to_integer(minutes)
      end
    end)
    |> Map.update!(:platform, &String.to_integer/1)
  end
end
