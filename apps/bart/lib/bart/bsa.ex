defmodule Bart.Bsa do
  defstruct date: nil, time: nil, messages: []

  @type t :: %__MODULE__{
          date: Date.t(),
          time: Time.t(),
          messages: [String.t()]
        }

  @endpoint "bsa"

  require Logger

  @doc """
  Get BART service advisories.
  """
  @spec get() :: Bart.Bsa.t | nil
  def get do
    :get
    |> Bart.make_request(@endpoint, %{cmd: "bsa"})
    |> handle_resp()
  end

  defp handle_resp({:error, _}), do: nil

  defp handle_resp({:ok, %{body: {:invalid, body}}}) do
    Logger.info("BART Response body: #{inspect(body)}")
    nil
  end

  defp handle_resp({:ok, %{body: %{"root" => root}, status_code: 200}}) do
    date =
      root
      |> Map.get("date")
      |> Timex.parse!("{0M}/{0D}/{YYYY}")
      |> Timex.to_date()

    time =
      root
      |> Map.get("time")
      |> Timex.parse!("{h24}:{m}:{s} {am} {Zabbr}")
      |> DateTime.to_time()

    messages =
      root
      |> Map.get("bsa")
      |> Enum.map(fn bsa ->
        get_in(bsa, ["description", "#cdata-section"])
      end)

    struct(__MODULE__, date: date, time: time, messages: messages)
  end

end
