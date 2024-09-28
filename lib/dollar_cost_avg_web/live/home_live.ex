defmodule DollarCostAvgWeb.HomeLive do
  use Phoenix.LiveView
  alias DollarCostAvg.Strategy

  def mount(_params, _session, socket) do
    # Default values
    socket =
      assign(socket, %{
        tickers: ["^GSPC", "AAPL", "AMZN", "GOOG", "MSFT", "NVDA", "PLTR", "TSLA"],
        dca_low: 0.80,
        dca_high: 0.98,
        results: []
      })

    {:ok, socket}
  end

  def handle_event("calculate", %{"tickers" => tickers, "dca_low" => dca_low, "dca_high" => dca_high}, socket) do
    tickers = String.split(tickers, ",")
    dca_low = String.to_float(dca_low)
    dca_high = String.to_float(dca_high)

    results = Enum.map(tickers, fn ticker ->
      Strategy.determine_strategy(ticker, dca_low, dca_high)
    end)

    {:noreply, assign(socket, results: results)}
  end
end
