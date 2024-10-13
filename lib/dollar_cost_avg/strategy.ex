defmodule DollarCostAvg.Strategy do
  @cache_expires_in :timer.hours(1)

  def determine_strategy(ticker, threshold_low, threshold_high) do
    with {:ok, market_data} <- fetch_market_data_with_cache(ticker) do
      {:ok, calculate_strategy(market_data, threshold_low, threshold_high, ticker)}
    end
  end

  defp build_url(ticker) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    one_year_ago = DateTime.add(DateTime.utc_now(), -365 * 24 * 60 * 60) |> DateTime.to_unix()

    path = "?period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
    "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}" <> path
  end

  require Logger

  defp fetch_market_data_with_cache(ticker) do
    now = :os.system_time(:millisecond)
    url = build_url(ticker)

    case :ets.lookup(__MODULE__, ticker) do
      [{^ticker, market_data, ttl}] when ttl > now ->
        Logger.info("Cache hit for #{ticker}")
        {:ok, market_data}

      _ ->
        case fetch_market_data(url) do
          {:ok, market_data} ->
            # Cache the data with a new TTL
            Logger.info("Cache miss for #{ticker}")
            :ets.insert(__MODULE__, {ticker, market_data, now + @cache_expires_in})
            {:ok, market_data}

          error ->
            error
        end
    end
  end

  defp fetch_market_data(url) do
    with {:ok, response} <- url |> URI.encode() |> Req.get(req_options()),
         response_body = response.body,
         [first_result | _] <- response_body["chart"]["result"],
         [first_indicator | _] <- first_result["indicators"]["quote"] do
      day_high = first_result["meta"]["regularMarketDayHigh"]
      year_high = Enum.max(first_indicator["high"])

      {:ok, %{day_high: day_high, year_high: year_high}}
    else
      {:error, request_error} -> {:error, request_error}
      _empty_or_nil -> {:error, "not found"}
    end
  end

  defp calculate_strategy(market_data, threshold_low, threshold_high, ticker) do
    threshold_aggressive = market_data.year_high * threshold_low
    threshold_normal = market_data.year_high * threshold_high

    {strategy, color} =
      determine_buy_strategy(market_data.day_high, threshold_aggressive, threshold_normal)

    %{
      ticker: ticker,
      daily_high: float_to_dollar(market_data.day_high),
      high_52_week: float_to_dollar(market_data.year_high),
      threshold_aggressive: float_to_dollar(threshold_aggressive),
      threshold_normal: float_to_dollar(threshold_normal),
      strategy: strategy,
      color: color,
      url: build_url(ticker)
    }
  end

  defp determine_buy_strategy(daily_high, threshold_aggressive, threshold_normal) do
    cond do
      daily_high < threshold_aggressive -> {"Buy aggressively", "blue"}
      daily_high < threshold_normal -> {"Buy normally", "green"}
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

# defmodule DollarCostAvg.Strategy do
#   def determine_strategy(ticker, threshold_low, threshold_high) do
#     url = build_url(ticker)
# 
#     with {:ok, market_data} <- fetch_market_data(url) do
#       {:ok, calculate_strategy(market_data, threshold_low, threshold_high, ticker, url)}
#     end
#   end
# 
#   defp build_url(ticker) do
#     current_time = DateTime.utc_now() |> DateTime.to_unix()
#     one_year_ago = DateTime.add(DateTime.utc_now(), -365 * 24 * 60 * 60) |> DateTime.to_unix()
# 
#     path = "?period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
#     "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}" <> path
#   end
# 
#   defp fetch_market_data(url) do
#     with {:ok, response} <- url |> URI.encode() |> Req.get(req_options()),
#          response_body = response.body,
#          [first_result | _] <- response_body["chart"]["result"],
#          [first_indicator | _] <- first_result["indicators"]["quote"] do
#       day_high = first_result["meta"]["regularMarketDayHigh"]
#       year_high = Enum.max(first_indicator["high"])
# 
#       {:ok, %{day_high: day_high, year_high: year_high}}
#     else
#       {:error, request_error} -> {:error, request_error}
#       _empty_or_nil -> {:error, "not found"}
#     end
#   end
# 
#   defp calculate_strategy(market_data, threshold_low, threshold_high, ticker, url) do
#     threshold_aggressive = market_data.year_high * threshold_low
#     threshold_normal = market_data.year_high * threshold_high
# 
#     {strategy, color} =
#       determine_buy_strategy(market_data.day_high, threshold_aggressive, threshold_normal)
# 
#     %{
#       ticker: ticker,
#       daily_high: float_to_dollar(market_data.day_high),
#       high_52_week: float_to_dollar(market_data.year_high),
#       threshold_aggressive: float_to_dollar(threshold_aggressive),
#       threshold_normal: float_to_dollar(threshold_normal),
#       strategy: strategy,
#       color: color,
#       url: url
#     }
#   end
# 
#   defp determine_buy_strategy(daily_high, threshold_aggressive, threshold_normal) do
#     cond do
#       daily_high < threshold_aggressive -> {"Buy aggressively", "blue"}
#       daily_high < threshold_normal -> {"Buy normally", "green"}
#       true -> {"Don't buy", "gray"}
#     end
#   end
# 
#   defp float_to_dollar(float) do
#     "$#{:erlang.float_to_binary(float, decimals: 2)}"
#   end
# 
#   defp req_options do
#     case get_proxy() do
#       nil -> []
#       proxy -> [connect_options: [proxy: proxy]]
#     end
#   end
# 
#   defp get_proxy do
#     https_proxy = System.get_env("HTTPS_PROXY")
#     http_proxy = System.get_env("HTTP_PROXY")
# 
#     (https_proxy && parse_proxy(https_proxy)) || (http_proxy && parse_proxy(http_proxy))
#   end
# 
#   defp parse_proxy(proxy_url) do
#     %URI{scheme: scheme, host: host, port: port} = URI.parse(proxy_url)
# 
#     case scheme do
#       "http" -> {:http, host, port, []}
#       "https" -> {:https, host, port, []}
#       _ -> nil
#     end
#   end
# end
