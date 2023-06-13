defmodule PlausibleWeb.Live.FunnelSettings.List do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~H"""
    <div>
    <%= if Enum.count(@funnels) > 0 do %>
      <div class="mt-4">
        <%= for funnel <- @funnels do %>
          <div class="border-b border-gray-300 dark:border-gray-500 py-3 flex justify-between">
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100"><%= funnel.name %></span>
            <%= button(to: "", method: :delete, class: "text-sm text-red-600", data: [confirm: "Are you sure you want to remove funnel '#{funnel.name}'? This will just affect the UI, all of your analytics data will stay intact."]) do %>
              <svg class="feather feather-sm" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="mt-4 dark:text-gray-100">No funnels configured for this site yet</div>
    <% end %>
    </div>
    """
  end
end
