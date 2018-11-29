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

  def get(params) do
    :get
    |> Bart.make_request(@endpoint, params)
    |> handle_resp()
  end

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
  end
end
