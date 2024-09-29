defmodule DollarCostAvgWeb.HomeLive do
  use DollarCostAvgWeb, :live_view
  alias DollarCostAvg.Strategy
 
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

  def handle_event("calculate", %{"tickers" => tickers, "dca_low" => dca_low, "dca_high" => dca_high}, socket) do
    tickers = tickers |> String.replace(" ", "") |> String.upcase() |> String.split(",") |> Enum.uniq() |> Enum.sort()
    dca_low = String.to_float(dca_low)
    dca_high = String.to_float(dca_high)

    results = Enum.map(tickers, fn ticker ->
      Strategy.determine_strategy(ticker, dca_low, dca_high)
    end)

    {:noreply, assign(socket, results: results, tickers: tickers)}
  end
end
