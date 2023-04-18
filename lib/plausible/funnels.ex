defmodule Plausible.Funnels do
  @funnel_window_duration 86_400

  alias Plausible.Funnel
  alias Plausible.Repo
  alias Plausible.ClickhouseRepo

  import Ecto.Changeset
  import Ecto.Query

  def create(site, name, goals, id \\ 5) when is_list(goals) do
    steps =
      goals
      |> Enum.with_index(1)
      |> Enum.map(fn {goal, index} ->
        %{
          goal_id: goal.id,
          step_order: index
        }
      end)

    change(%Funnel{
      site_id: site.id,
      name: name,
      id: id
    })
    |> put_assoc(:steps, steps)
    |> Repo.insert!()
  end

  def get(%Plausible.Site{id: site_id}, by) do
    get(site_id, by)
  end

  def get(site_id, funnel_id) when is_integer(site_id) and is_integer(funnel_id) do
    q =
      from f in Funnel,
        where: f.site_id == ^site_id,
        where: f.id == ^funnel_id,
        inner_join: steps in assoc(f, :steps),
        inner_join: goal in assoc(steps, :goal),
        preload: [
          steps: {steps, goal: goal}
        ]

    Repo.one(q)
  end

  def evaluate(query, funnel_id, site_id) do
    funnel = get(site_id, funnel_id)

    q_events =
      from(e in "events_v2",
        select: %{
          session_id: e.session_id
        },
        where: e.site_id == ^funnel.site_id,
        group_by: e.session_id,
        having: fragment("step > 0"),
        order_by: [desc: fragment("step")]
      )
      |> select_funnel(query)

    query =
      from f in subquery(q_events),
        select: {f.step, count(1)},
        group_by: f.step

    funnel_result =
      ClickhouseRepo.all(query)
      |> Enum.into(%{})

    steps = update_step_defaults(funnel, funnel_result)

    %{
      name: funnel.name,
      steps: steps
    }
  end

  defp select_funnel(db_query, _stats_query) do
    from(
      q in db_query,
      select_merge: %{
        step:
          fragment(
            "windowFunnel(?)(timestamp, ?, ?, ?, ?)",
            @funnel_window_duration
          )
      }
    )
  end

  defp funnel_step_conditions() do
  end

  defp update_step_defaults(funnel, funnel_result) do
    max_step = Enum.max_by(funnel.steps, & &1.step_order).step_order

    funnel.steps
    |> Enum.map(fn step ->
      label = Plausible.Goal.display_name(step.goal)

      visitors_total =
        Enum.reduce(step.step_order..max_step, 0, fn step_order, acc ->
          visitors = Map.get(funnel_result, step_order, 0)

          acc + visitors
        end)

      %{
        visitors: visitors_total,
        label: label
      }
    end)
  end
end
