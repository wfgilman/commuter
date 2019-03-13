defmodule Core.ServiceAdvisory do
  defstruct count: nil, advisory: nil

  @type t :: %__MODULE__{
          count: integer,
          advisory: String.t()
        }

  import Core.Utils

  @doc """
  Returns BART service advisories.
  """
  @spec get() :: {integer, String.t()}
  def get do
    with bsa when not is_nil(bsa) <- Bart.Bsa.get(),
         true <- bsa.date == today(),
         "No delays reported." <- Enum.at(bsa.messages, 1) do
      advisory =
        Enum.reduce(bsa.messages, fn msg, acc ->
          "#{acc} #{msg}"
        end)

      count = Enum.count(bsa.messages)

      struct(__MODULE__, count: count, advisory: advisory)
    else
      _ ->
        struct(__MODULE__, count: 0, advisory: "No advisory info.")
    end
  end
end
