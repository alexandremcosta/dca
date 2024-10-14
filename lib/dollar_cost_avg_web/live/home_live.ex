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

  def handle_event(
        "calculate",
        %{"tickers" => tickers, "dca_low" => dca_low, "dca_high" => dca_high},
        socket
      ) do
    tickers = parse_tickers(tickers)
    dca_low = String.to_float(dca_low)
    dca_high = String.to_float(dca_high)

    results = calculate_strategies(tickers, dca_low, dca_high)
    socket = flash_errors(socket, results.error)

    {:noreply, assign(socket, results: results.ok, tickers: tickers)}
  end

  defp parse_tickers(tickers) do
    tickers
    |> String.replace(" ", "")
    |> String.upcase()
    |> String.split(",")
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp calculate_strategies(tickers, dca_low, dca_high) do
    Enum.reduce(tickers, %{ok: [], error: []}, fn ticker, acc ->
      case Strategy.fetch_strategy(ticker, dca_low, dca_high) do
        {:ok, strategy} -> %{acc | ok: [strategy | acc.ok]}
        {:error, error} -> %{acc | error: [{ticker, error} | acc.error]}
      end
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
