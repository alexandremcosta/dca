defmodule DollarCostAvg.Strategy do
  def determine_strategy(ticker, threshold_low, threshold_high) do
    current_time = DateTime.utc_now()
    one_year_ago = DateTime.add(current_time, -365 * 24 * 60 * 60)

    current_time = DateTime.to_unix(current_time)
    one_year_ago = DateTime.to_unix(one_year_ago)

    path = "?period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}" <> path
    proxy = build_proxy()

    response =
      url
      |> URI.encode()
      |> Req.get!(connect_options: [proxy: proxy])
      |> Map.fetch!(:body)

    first_result = List.first(response["chart"]["result"])
    first_indicator = List.first(first_result["indicators"]["quote"])
    high_52_week = Enum.max(first_indicator["high"])
    daily_high = first_result["meta"]["regularMarketDayHigh"]

    threshold_aggressive = high_52_week * threshold_low
    threshold_normal = high_52_week * threshold_high

    {strategy, color} =
      cond do
        daily_high < threshold_aggressive -> {"Buy aggressively", "blue"}
        daily_high < threshold_normal -> {"Buy normally", "green"}
        true -> {"Don't buy", "gray"}
      end

    %{
      ticker: ticker,
      daily_high: float_to_dollar(daily_high),
      high_52_week: float_to_dollar(high_52_week),
      threshold_aggressive: float_to_dollar(threshold_aggressive),
      threshold_normal: float_to_dollar(threshold_normal),
      strategy: strategy,
      color: color,
      url: url
    }
  end

  defp float_to_dollar(float) do
    "$#{:erlang.float_to_binary(float, decimals: 2)}"
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
