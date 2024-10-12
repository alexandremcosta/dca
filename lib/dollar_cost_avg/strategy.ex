defmodule DollarCostAvg.Strategy do
  def determine_strategy(ticker, threshold_low, threshold_high) do
    current_time = DateTime.utc_now()
    one_year_ago = DateTime.add(current_time, -365 * 24 * 60 * 60)

    current_time = DateTime.to_unix(current_time)
    one_year_ago = DateTime.to_unix(one_year_ago)

    path = "?period2=#{current_time}&period1=#{one_year_ago}&interval=1d"
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}" <> path

    with {:ok, response} <- url |> URI.encode() |> Req.get(req_options()),
         response = response.body,
         [first_result | _] <- response["chart"]["result"],
         [first_indicator | _] <- first_result["indicators"]["quote"] do
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

      {:ok,
       %{
         ticker: ticker,
         daily_high: float_to_dollar(daily_high),
         high_52_week: float_to_dollar(high_52_week),
         threshold_aggressive: float_to_dollar(threshold_aggressive),
         threshold_normal: float_to_dollar(threshold_normal),
         strategy: strategy,
         color: color,
         url: url
       }}
    else
      {:error, request_error} -> {:error, request_error}
      nil -> {:error, "not found"}
    end
  end

  defp float_to_dollar(float) do
    "$#{:erlang.float_to_binary(float, decimals: 2)}"
  end

  defp req_options do
    https_proxy = System.get_env("HTTPS_PROXY")
    http_proxy = System.get_env("HTTP_PROXY")

    proxy =
      cond do
        https_proxy ->
          parse_proxy(https_proxy)

        http_proxy ->
          parse_proxy(http_proxy)

        true ->
          nil
      end

    options = if proxy, do: [proxy: proxy], else: []
    [connect_options: options]
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
