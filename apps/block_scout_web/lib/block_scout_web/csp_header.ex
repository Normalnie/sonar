defmodule BlockScoutWeb.CSPHeader do
  @moduledoc """
  Plug to set content-security-policy with websocket endpoints
  """

  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    Controller.put_secure_browser_headers(conn, %{
      "content-security-policy" => "\
        connect-src 'self' #{websocket_endpoints(conn)} wss://*.bridge.walletconnect.org/ https://request-global.czilladx.com/ https://raw.githubusercontent.com/trustwallet/assets/ https://raw.githubusercontent.com/dogmoneyswap/assets/ https://registry.walletconnect.org/data/wallets.json https://registry.walletconnect.com/api/v2/wallets https://matomo.mistswap.fi/ http://matomo.mistswap.fi/ https://*.dogmoney.money/;\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' https://coinzillatag.com/ https://www.google.com/ https://www.gstatic.com/ https://matomo.mistswap.fi/;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com/;\
        img-src 'self' * data:;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com/ data:;\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' https://request-global.czilladx.com/ https://www.google.com/;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
