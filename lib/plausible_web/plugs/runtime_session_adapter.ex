defmodule PlausibleWeb.Plugs.RuntimeSessionAdapter do
  @moduledoc """
  A `Plug.Session` adapter that allows configuration at runtime.
  Sadly, the plug being wrapped has no MFA option for dynamic
  configuration.

  This is currently used so we can dynamically pass the :domain
  and have cookies planted across one root domain.
  """

  @behaviour Plug

  @impl true
  def init(opts) do
    Plug.Session.init(opts)
  end

  @impl true
  def call(conn, opts) do
    conn = patch_cookie_domain(conn, opts)
    Plug.Session.call(conn, opts)
  end

  defp patch_cookie_domain(conn, %{cookie_opts: cookie_opts} = runtime_opts) do
    # Obter o valor do cabeçalho "host" da requisição
    host_header = Plug.Conn.get_req_header(conn, "host")

    domain = host_header

    Map.replace(
      runtime_opts,
      :cookie_opts,
      Keyword.put_new(cookie_opts, :domain, domain)
    )
  end
end
