defmodule Bart do
  use HTTPoison.Base

  def make_request(method, endpoint, params) do
    endpoint = "#{endpoint}.aspx?" <> encode_params(params)
    request(method, endpoint)
  end

  def process_url(endpoint) do
    Application.get_env(:bart, :root_uri) <> endpoint
  end

  def process_response_body(body) do
    Poison.Parser.parse!(body)
  end

  def encode_params(params) do
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
