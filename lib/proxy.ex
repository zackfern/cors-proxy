defmodule Proxy do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug :dispatch

  @include_headers ["Content-Type"]

  def init(options) do
    options
  end

  @doc "Starts the Cowboy HTTP server"
  def start do
    {:ok, _} = Plug.Adapters.Cowboy.http __MODULE__, []
  end

  get "/" do
    conn = conn
      |> fetch_query_params
      |> merge_resp_headers([{"access-control-allow-origin", "*"}])
    url = conn.query_params["url"]

    unless url do
      conn |> send_resp(404, "404") |> halt
    end

    {status, response} = HTTPoison.get(url)
    handle_response(conn, status, response)
  end

  def handle_response(conn, :ok, %HTTPoison.Response{status_code: 200, body: body, headers: headers}) do
    headers = headers
      |> Enum.filter(fn({key, _}) -> Enum.member?(@include_headers, key) end)
    conn
      |> merge_resp_headers(headers)
      |> send_resp(200, body)
      |> halt
  end

  def handle_response(conn, :ok, %HTTPoison.Response{status_code: status}) do
    conn |> send_resp(status, "HTTP #{status}") |> halt
  end

  def handle_response(conn, :error, %HTTPoison.Error{reason: error}) do
    conn |> send_resp(500, error) |> halt
  end

  match _ do
    conn |> send_resp(404, "404") |> halt
  end
end

Proxy.start
