defmodule PlausibleWeb.Live.FunnelSettings.InputPicker do
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS

  @max_options_displayed 15

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:candidate, 0)
      |> assign_new(:choices, fn ->
        Enum.take(assigns.options, @max_options_displayed)
      end)

    {:ok, socket}
  end

  attr(:placeholder, :string, default: "Select option or search by typing")
  attr(:id, :any, default: nil)
  attr(:options, :list, required: true)
  attr(:submit_name, :string, required: true)
  attr(:display_value, :string, default: "")
  attr(:submit_value, :string, default: "")

  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <div class="relative w-full">
        <div
          phx-click-away={close_dropdown(@id)}
          class="pl-2 pr-8 py-1 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500"
        >
          <input
            type="text"
            autocomplete="off"
            id={@id}
            name={"display-#{@id}"}
            placeholder={@placeholder}
            phx-keyup="keypress"
            phx-focus={open_dropdown(@id)}
            phx-target={@myself}
            value={@display_value}
            class="border-none py-1 px-1 p-0 w-full inline-block rounded-md focus:outline-none focus:ring-0 text-sm"
            style="background-color: inherit;"
          />

          <.dropdown_anchor id={@id} />

          <input
            type="hidden"
            name={@submit_name}
            value={@submit_value}
            phx-change="update-value"
            phx-target={@myself}
            id={"submit-#{@id}"}
          />
        </div>
      </div>

      <.dropdown
        ref={@id}
        options={@options}
        choices={@choices}
        target={@myself}
        candidate={@candidate}
      />
    </div>
    """
  end

  attr(:id, :any, required: true)

  def dropdown_anchor(assigns) do
    ~H"""
    <div
      phx-click={open_dropdown(@id)}
      class="cursor-pointer absolute inset-y-0 right-0 flex items-center pr-2"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
        class="h-4 w-4 text-gray-500"
      >
        <path
          fill-rule="evenodd"
          d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
          clip-rule="evenodd"
        >
        </path>
      </svg>
    </div>
    """
  end

  def open_dropdown(js \\ %JS{}, id) do
    js
    |> close_all_dropdowns()
    |> JS.remove_class("hidden", to: "#dropdown-#{id}")
  end

  def close_dropdown(js \\ %JS{}, id) do
    JS.add_class(js, "hidden", to: "#dropdown-#{id}")
  end

  def close_all_dropdowns(js \\ %JS{}) do
    JS.add_class(js, "hidden", to: ".dropdown")
  end

  attr(:ref, :string, required: true)
  attr(:options, :list, default: [])
  attr(:choices, :list, default: [])
  attr(:candidate, :integer, required: true)
  attr(:target, :any)

  def dropdown(assigns) do
    ~H"""
    <ul
      tabindex="-1"
      id={"dropdown-#{@ref}"}
      class="dropdown hidden z-50 absolute mt-1 max-h-60 overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900"
    >
      <.option
        :for={{{submit_value, display_value}, idx} <- Enum.with_index(@choices)}
        :if={@choices != []}
        idx={idx}
        submit_value={submit_value}
        display_value={display_value}
        target={@target}
        ref={@ref}
        candidate={@candidate}
      />

      <div
        :if={@choices == []}
        class="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300"
      >
        No matches found. Try searching for something different.
      </div>
    </ul>
    """
  end

  attr(:display_value, :string, required: true)
  attr(:submit_value, :integer, required: true)
  attr(:ref, :string, required: true)
  attr(:target, :any)
  attr(:idx, :integer, required: true)
  attr(:candidate, :integer, required: true)

  def option(assigns) do
    assigns = assign(assigns, :max_options_displayed, @max_options_displayed)

    ~H"""
    <li
      class={[
        "relative select-none py-2 px-3 cursor-pointer dark:text-gray-300",
        @idx == @candidate && "text-white bg-indigo-500"
      ]}
      id={"dropdown-#{@ref}-option-#{@idx}"}
    >
      <a
        phx-click={select_option(@ref, @submit_value, @display_value)}
        phx-value-display-value={@display_value}
        phx-target={@target}
      >
        <span class="block truncate">
          <%= @display_value %>
        </span>
      </a>
    </li>
    <li :if={@idx == @max_options_displayed - 1} class="text-xs text-gray-500 relative py-2 px-3">
      Max results reached. Refine your search by typing in goal name.
    </li>
    """
  end

  def select_option(js \\ %JS{}, id, submit_value, display_value) do
    js
    |> JS.push("select-option",
      value: %{"submit-value" => submit_value, "display-value" => display_value}
    )
    |> close_dropdown(id)
  end

  def handle_event(
        "select-option",
        %{"submit-value" => submit_value, "display-value" => display_value},
        socket
      ) do
    socket = do_select(socket, submit_value, display_value)
    {:noreply, socket}
  end

  def handle_event(
        "keypress",
        %{"key" => "ArrowDown"},
        %{
          assigns: %{candidate: c, choices: choices, id: id}
        } = socket
      )
      when c < length(choices) - 1 do
    socket =
      socket
      |> push_event("scroll-to", %{id: "dropdown-#{id}-option-#{c}"})
      |> assign(candidate: c + 1)

    {:noreply, socket}
  end

  def handle_event(
        "keypress",
        %{"key" => "ArrowUp"},
        %{
          assigns: %{candidate: c, id: id}
        } = socket
      )
      when c > 0 do
    socket =
      socket
      |> push_event("scroll-to", %{id: "dropdown-#{id}-option-#{c}"})
      |> assign(candidate: c - 1)

    {:noreply, socket}
  end

  def handle_event(
        "keypress",
        %{"key" => "Enter"},
        %{assigns: %{candidate: c, choices: choices}} = socket
      ) do
    socket =
      case Enum.at(choices, c) do
        {submit_value, display_value} ->
          do_select(socket, submit_value, display_value)

        nil ->
          assign(socket, candidate: 0)
      end

    {:noreply, socket}
  end

  def handle_event("keypress", %{"key" => "Escape"}, socket) do
    socket = do_select(socket, "", "")
    {:noreply, socket}
  end

  def handle_event("keypress", %{"key" => _other, "value" => input}, socket) do
    if String.length(input) > 0 do
      choices =
        Enum.sort_by(
          socket.assigns.options,
          fn {_, value} ->
            if value == input do
              3
            else
              input = String.downcase(input)
              value = String.downcase(value)
              weight = if String.contains?(value, input), do: 1, else: 0
              weight + String.jaro_distance(value, input)
            end
          end,
          :desc
        )
        |> Enum.take(@max_options_displayed)

      {:noreply, assign(socket, %{choices: choices, candidate: 0})}
    else
      {:noreply,
       assign(socket, %{
         choices: Enum.take(socket.assigns.options, @max_options_displayed),
         candidate: 0
       })}
    end
  end

  defp do_select(socket, submit_value, display_value) do
    id = socket.assigns.id

    socket
    |> push_event("update-value", %{id: id, value: display_value})
    |> push_event("hide", %{id: "dropdown-#{id}"})
    |> assign(:candidate, 0)
    |> assign(:display_value, display_value)
    |> assign(:submit_value, submit_value)
  end
end
