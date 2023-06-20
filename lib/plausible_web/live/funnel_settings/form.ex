defmodule PlausibleWeb.Live.FunnelSettings.Form do
  @moduledoc """
  Phoenix LiveComponent that renders a form used for setting up funnels.
  Makes use of dynamically placed `PlausibleWeb.Live.FunnelSettings.ComboBox` components
  to allow building searchable funnel definitions out of list of goals available.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  use Plausible.Funnel

  def mount(socket) do
    {:ok, assign(socket, step_ids: Enum.to_list(1..Funnel.min_steps()))}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       form: assigns.form,
       goals: assigns.goals,
       site: assigns.site
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-4 gap-6 mt-6">
      <div class="col-span-4 sm:col-span-2">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="save"
          onkeydown="return event.key != 'Enter';"
        >
          <%= label(f, "Funnel name",
            class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
          ) %>
          <.input field={f[:name]} />

          <div id="steps-builder">
            <%= label(f, "Funnel Steps",
              class: "mt-6 block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
            ) %>

            <div :for={step_idx <- @step_ids} class="flex">
              <div class="w-full flex-1">
                <.live_component
                  submit_name="funnel[steps][][goal_id]"
                  module={PlausibleWeb.Live.FunnelSettings.ComboBox}
                  id={"step-#{step_idx}"}
                  options={@goals}
                />
              </div>

              <.remove_step_button
                :if={length(@step_ids) > Funnel.min_steps()}
                target={@myself}
                step_idx={step_idx}
              />
            </div>

            <.add_step_button :if={length(@step_ids) < Funnel.max_steps()} target={@myself} />

            <div class="mt-6">
              <%= if has_steps_errors?(f) do %>
                <.submit_button_inactive />
              <% else %>
                <.submit_button />
              <% end %>
              <.cancel_button />
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr(:field, Phoenix.HTML.FormField)

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@field.name}>
      <input
        autocomplete="off"
        autofocus
        type="text"
        id={@field.id}
        name={@field.name}
        value={@field.value}
        phx-debounce="300"
        class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-full rounded-md sm:text-sm border-gray-300 dark:border-gray-500"
      />

      <.error :for={{msg, _} <- @field.errors}>Funnel name <%= msg %></.error>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <div class="mt-2 text-sm text-red-600">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :step_idx, :integer, required: true
  attr :target, :any

  def remove_step_button(assigns) do
    ~H"""
    <div class="inline-flex items-center ml-2 mb-2 text-red-600">
      <svg
        id={"remove-step-#{@step_idx}"}
        class="feather feather-sm cursor-pointer"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        phx-click="remove-step"
        phx-target={@target}
        phx-value-step-idx={@step_idx}
      >
        <polyline points="3 6 5 6 21 6"></polyline>
        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2">
        </path>
        <line x1="10" y1="11" x2="10" y2="17"></line>
        <line x1="14" y1="11" x2="14" y2="17"></line>
      </svg>
    </div>
    """
  end

  attr :target, :any

  def add_step_button(assigns) do
    ~H"""
    <a
      class="underline text-indigo-600 text-sm cursor-pointer mt-6"
      phx-click="add-step"
      phx-target={@target}
    >
      + Add another step
    </a>
    """
  end

  def submit_button(assigns) do
    ~H"""
    <button id="save" type="submit" class="button mt-6">Save</button>
    """
  end

  def submit_button_inactive(assigns) do
    ~H"""
    <button
      type="none"
      id="save"
      class="inline-block mt-6 px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-gray-300 bg-white dark:bg-gray-800 hover:text-gray-500 dark:hover:text-gray-400 focus:outline-none focus:border-blue-300 focus:ring active:text-gray-800 active:bg-gray-50 transition ease-in-out duration-150 cursor-not-allowed"
    >
      Save
    </button>
    """
  end

  def cancel_button(assigns) do
    ~H"""
    <button
      type="button"
      id="cancel"
      class="inline-block mt-4 ml-2 px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-red-700 bg-white dark:bg-gray-800 hover:text-red-500 dark:hover:text-red-400 focus:outline-none focus:border-blue-300 focus:ring active:text-red-800 active:bg-gray-50 transition ease-in-out duration-150 "
      phx-click="cancel-add-funnel"
    >
      Cancel
    </button>
    """
  end

  def handle_event("add-step", _value, socket) do
    step_ids = socket.assigns.step_ids

    if length(step_ids) < Funnel.max_steps() do
      first_free_idx = find_sequence_break(step_ids)
      new_ids = step_ids ++ [first_free_idx]
      {:noreply, assign(socket, step_ids: new_ids)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove-step", %{"step-idx" => idx}, socket) do
    idx = String.to_integer(idx)
    step_ids = List.delete(socket.assigns.step_ids, idx)
    {:noreply, assign(socket, step_ids: step_ids)}
  end

  def handle_event("validate", %{"funnel" => params}, socket) do
    changeset =
      socket.assigns.site
      |> Plausible.Funnels.create_changeset(
        params["name"],
        params["steps"] || []
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"funnel" => params}, %{assigns: %{site: site}} = socket) do
    case Plausible.Funnels.create(site, params["name"], params["steps"]) do
      {:ok, funnel} ->
        send(self(), {:funnel_saved, Map.put(funnel, :steps_count, length(params["steps"]))})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  defp find_sequence_break(input) do
    input
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.reduce_while(nil, fn {x, order}, _ ->
      if x != order do
        {:halt, order}
      else
        {:cont, order + 1}
      end
    end)
  end

  defp has_steps_errors?(f) do
    not f.source.valid?
  end
end
