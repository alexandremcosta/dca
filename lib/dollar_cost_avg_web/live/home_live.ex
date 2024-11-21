defmodule DollarCostAvgWeb.HomeLive do
  use DollarCostAvgWeb, :live_view
  alias DollarCostAvg.Strategy
  require Logger

  def mount(_params, _session, socket) do
    # Default values
    socket =
      assign(socket, %{
        tickers: ["AAPL", "AMZN", "GOOG", "MSFT", "NVDA", "PLTR", "TSLA", "^GSPC"],
        dca_low: 0.80,
        dca_high: 0.98,
        results: []
      })

    {:ok, socket, layout: false}
  end

  def handle_params(params, _uri, socket) do
    tickers = parse_tickers(params["tickers"] || socket.assigns.tickers)
    dca_low = parse_float(params["dca_low"], socket.assigns.dca_low)
    dca_high = parse_float(params["dca_high"], socket.assigns.dca_high)

    socket = assign(socket, tickers: tickers, dca_low: dca_low, dca_high: dca_high)
    socket = if params["tickers"], do: calculate_strategies(socket), else: socket

    {:noreply, socket}
  end

  def handle_event(
        "calculate",
        %{"tickers" => tickers, "dca_low" => dca_low, "dca_high" => dca_high},
        socket
      ) do
    {:noreply,
     push_patch(socket, to: ~p"/?#{[tickers: tickers, dca_low: dca_low, dca_high: dca_high]}")}
  end

  defp parse_tickers(tickers) when is_binary(tickers) do
    tickers
    |> String.replace(" ", "")
    |> String.upcase()
    |> String.split(",")
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp parse_tickers(tickers) when is_list(tickers), do: tickers

  defp parse_float(value, default) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> default
    end
  end

  defp parse_float(_, default), do: default

  defp calculate_strategies(socket) do
    %{tickers: tickers, dca_low: dca_low, dca_high: dca_high} = socket.assigns
    %{ok: strategies, error: errors} = do_calculate_strategies(tickers, dca_low, dca_high)

    socket
    |> flash_errors(errors)
    |> assign(results: strategies)
  end

  defp do_calculate_strategies(tickers, dca_low, dca_high) do
    tickers
    |> Task.async_stream(fn ticker ->
      {ticker, Strategy.fetch_strategy(ticker, dca_low, dca_high)}
    end)
    |> Enum.reduce(%{ok: [], error: []}, fn
      {:ok, {_ticker, {:ok, strategy}}}, acc -> %{acc | ok: [strategy | acc.ok]}
      {:ok, {ticker, {:error, error}}}, acc -> %{acc | error: [{ticker, error} | acc.error]}
    end)
  end

  defp flash_errors(socket, errors) do
    errors =
      for {ticker, error} <- errors do
        msg = "Cannot calculate strategy for #{ticker}: #{inspect(error)}"
        Logger.error(msg)
        raw("<p>#{msg}</p>")
      end

    if Enum.any?(errors) do
      put_flash(socket, :error, Enum.intersperse(errors, raw("<br>")))
    else
      socket
    end
  end
end
