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

    runtime_opts_with_domain =
      Map.update!(runtime_opts, :cookie_opts, fn opts ->
        Keyword.put_new(opts, :domain, domain)
      end)

    # Criar uma nova conexão com os valores atualizados em runtime_opts
    %Plug.Conn{conn | private: runtime_opts_with_domain}
  end

end
