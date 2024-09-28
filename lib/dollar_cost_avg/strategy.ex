defmodule DollarCostAvg.Strategy do
  def determine(ticker, threshold_low, threshold_high) do
    current_time = DateTime.utc_now()
    one_year_ago = DateTime.add(current_time, -365 * 24 * 60 * 60)

    current_time = DateTime.to_unix(current_time)
    one_year_ago = DateTime.to_unix(one_year_ago)

    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}"
    path = "period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
    proxy = build_proxy()

    response =
      (url <> "?" path)
      |> URI.encode()
      |> Req.get!(connect_options: [proxy: proxy])
      |> Map.fetch!(:body)

    first_result = List.first(response["chart"]["result"])
    first_indicator = List.first(first_result["indicators"]["quote"])
    high_52_week = Enum.max(first_indicator["high"])
    daily_high = first_result["meta"]["regularMarketDayHigh"]

    strategy =
      cond do
        daily_high < high_52_week * threshold_low -> "Buy aggressively"
        daily_high < high_52_week * threshold_high -> "Buy normally"
        true -> "Don't buy"
      end

    %{
      ticker: ticker,
      daily_high: daily_high,
      high_52_week: high_52_week,
      threshold_aggressive: threshold_aggressive,
      threshold_normal: threshold_normal,
      strategy: strategy
    }
  end

  defp build_proxy do
    https_proxy = System.get_env("HTTPS_PROXY")
    http_proxy = System.get_env("HTTP_PROXY")

    cond do
      https_proxy ->
        parse_proxy(https_proxy)

      http_proxy ->
        parse_proxy(http_proxy)

      true ->
        nil
    end
  end

  defp parse_proxy(proxy_url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(proxy_url)

    case scheme do
      "http" -> {:http, host, port, []}
      "https" -> {:https, host, port, []}
      _ -> nil
    end
  end
end
