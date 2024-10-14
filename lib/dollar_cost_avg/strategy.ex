defmodule DollarCostAvg.Strategy do
  def determine_strategy(ticker, threshold_low, threshold_high) do
    with {:ok, ticker_prices} <- fetch_day_and_year_high(ticker) do
      {:ok, calculate_strategy(ticker_prices, threshold_low, threshold_high, ticker)}
    end
  end

  defp fetch_day_and_year_high(ticker) do
    url = build_url(ticker)

    fetch_cache(ticker, fn ->
      with {:ok, response} <- url |> URI.encode() |> Req.get(req_options()),
           response_body = response.body,
           [first_result | _] <- response_body["chart"]["result"],
           [first_indicator | _] <- first_result["indicators"]["quote"] do
        day_high = first_result["meta"]["regularMarketDayHigh"]
        year_high = Enum.max(first_indicator["high"])

        {:ok, {day_high, year_high}}
      else
        {:error, request_error} -> {:error, request_error}
        [] -> {:error, "not found"}
        nil -> {:error, "not found"}
      end
    end)
  end

  defp fetch_cache(key, function) do
    now = :os.system_time(:millisecond)

    case :ets.lookup(__MODULE__, key) do
      [{^key, data, ttl}] when ttl > now ->
        {:ok, data}

      _not_found_or_expired ->
        with {:ok, data} <- function.() do
          :ets.insert(__MODULE__, {key, data, now + :timer.hours(1)})
          {:ok, data}
        end
    end
  end

  defp calculate_strategy({day_high, year_high}, threshold_low, threshold_high, ticker) do
    aggressive_limit = year_high * threshold_low
    conservative_limit = year_high * threshold_high
    {strategy, color} = get_strategy_color(day_high, aggressive_limit, conservative_limit)

    %{
      ticker: ticker,
      daily_high: float_to_dollar(day_high),
      high_52_week: float_to_dollar(year_high),
      threshold_aggressive: float_to_dollar(aggressive_limit),
      threshold_normal: float_to_dollar(conservative_limit),
      strategy: strategy,
      color: color,
      url: build_url(ticker)
    }
  end

  defp build_url(ticker) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    one_year_ago = DateTime.add(DateTime.utc_now(), -365 * 24 * 60 * 60) |> DateTime.to_unix()

    path = "?period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
    "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}" <> path
  end

  defp get_strategy_color(daily_high, aggressive_limit, conservative_limit) do
    cond do
      daily_high < aggressive_limit -> {"Buy aggressively", "blue"}
      daily_high < conservative_limit -> {"Buy normally", "green"}
      true -> {"Don't buy", "gray"}
    end
  end

  defp float_to_dollar(float) do
    "$#{:erlang.float_to_binary(float, decimals: 2)}"
  end

  defp req_options do
    case get_proxy() do
      nil -> []
      proxy -> [connect_options: [proxy: proxy]]
    end
  end

  defp get_proxy do
    https_proxy = System.get_env("HTTPS_PROXY")
    http_proxy = System.get_env("HTTP_PROXY")

    (https_proxy && parse_proxy(https_proxy)) || (http_proxy && parse_proxy(http_proxy))
  end

  defp parse_proxy(proxy_url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(proxy_url)

    case scheme do
      "http" -> {:http, host, port, []}
      "https" -> {:https, host, port, []}
      _ -> nil
    end
  end

  def create_cache do
    :ets.new(__MODULE__, [:named_table, :set, :public, read_concurrency: true])
  end
end
