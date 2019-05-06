defmodule Api.RateLimit do
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  @doc """
  Rate limiting plug. Requires options:
  * `interval_seconds`
  * `max_requests`
  * `bucket_name` (optional)
  """
  @spec rate_limit(Plug.Conn.t, Plug.opts) :: Plug.Conn.t
  def rate_limit(conn, opts) do
    case check_rate(conn, opts) do
      {:ok, _count} ->
        conn
      {:error, _count} ->
        Logger.warn(fn ->
          bucket = opts[:bucket_name] || default_bucket_name(conn)
          "Rate limit violation for bucket: #{inspect bucket}"
        end)
        render_error(conn)
    end
  end

  defp check_rate(conn, opts) do
    interval_milliseconds = opts[:interval_seconds] * 1_000
    max_requests = opts[:max_requests]
    bucket_name = opts[:bucket_name] || default_bucket_name(conn)
    ExRated.check_rate(bucket_name, interval_milliseconds, max_requests)
  end

  defp default_bucket_name(conn) do
    path = Enum.join(conn.path_info, "/")
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    "#{ip_address}:#{path}"
  end

  defp render_error(conn) do
    conn
    |> put_status(429)
    |> put_view(ApiWeb.ErrorView)
    |> render("rate_limit.json")
    |> halt()
  end
end
