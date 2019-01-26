defmodule Bart do
  use HTTPoison.Base

  @doc """
  Makes HTTP Request to Bart API
  """
  @spec make_request(atom, String.t(), map) ::
          {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def make_request(method, endpoint, params) do
    p =
      params
      |> Map.merge(%{json: "y"})
      |> Map.to_list()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    endpoint = "#{endpoint}.aspx?" <> encode_params(p)
    request(method, endpoint)
  end

  def process_url(endpoint) do
    Application.get_env(:bart, :root_uri) <> endpoint
  end

  def process_response_body(body) do
    case Poison.Parser.parse(body) do
      {:ok, parsed_body} -> parsed_body
      {:error, _} -> {:invalid, body}
    end
  end

  defp encode_params(params) do
    params
    |> Map.merge(%{key: Application.get_env(:bart, :api_key)})
    |> Map.to_list()
    |> Enum.map_join("&", fn {key, value} ->
      param_name = key |> to_string() |> URI.encode_www_form()
      param_value = value |> to_string() |> URI.encode_www_form()
      "#{param_name}=#{param_value}"
    end)
  end
end
