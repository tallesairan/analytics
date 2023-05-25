defmodule Plausible.FunnelsTest do
  use Plausible.DataCase

  alias Plausible.Goals
  alias Plausible.Funnels

  setup do
    site = insert(:site)

    {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
    {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})
    {:ok, g4} = Goals.create(site, %{"event_name" => "Leave feedback"})
    {:ok, g5} = Goals.create(site, %{"page_path" => "/recommend"})
    {:ok, g6} = Goals.create(site, %{"event_name" => "Extra event"})

    {:ok, %{site: site, steps: [g1, g2, g3, g4, g5, g6] |> Enum.map(&%{"goal_id" => &1.id})}}
  end

  test "create and store a funnel given a set of goals", %{site: site, steps: [g1, g2, g3 | _]} do
    {:ok, funnel} =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        [g1, g2, g3]
      )

    assert funnel.inserted_at
    assert funnel.name == "From blog to signup and purchase"
    assert [fg1, fg2, fg3] = funnel.steps

    assert fg1.goal_id == g1["goal_id"]
    assert fg2.goal_id == g2["goal_id"]
    assert fg3.goal_id == g3["goal_id"]

    assert fg1.step_order == 1
    assert fg2.step_order == 2
    assert fg3.step_order == 3
  end

  test "retrieve a funnel by id and site, get steps in order", %{
    site: site,
    steps: [g1, g2, g3 | _]
  } do
    {:ok, funnel} =
      Funnels.create(
        site,
        "Lorem ipsum",
        [g3, g1, g2]
      )

    assert {:ok, funnel} = Funnels.get(site, funnel.id)
    assert funnel.name == "Lorem ipsum"
    assert [%{step_order: 1}, %{step_order: 2}, %{step_order: 3}] = funnel.steps
  end

  test "a funnel cannot be made of < 2 steps", %{site: site, steps: [g1 | _]} do
    assert {:error, :invalid_funnel_size} =
             Funnels.create(
               site,
               "Lorem ipsum",
               [g1]
             )
  end

  test "a funnel can be made of 5 steps maximum", %{site: site, steps: too_many_steps} do
    assert {:error, :invalid_funnel_size} =
             Funnels.create(
               site,
               "Lorem ipsum",
               too_many_steps
             )
  end

  test "a goal can only appear once in a funnel", %{steps: [g1 | _], site: site} do
    {:error, _changeset} =
      Funnels.create(
        site,
        "Lorem ipsum",
        [g1, g1]
      )
  end

  test "funnels can be listed per site, starting from most recently added", %{
    site: site,
    steps: [g1, g2, g3 | _]
  } do
    Funnels.create(site, "Funnel 1", [g3, g1])
    Funnels.create(site, "Funnel 2", [g2, g1, g3])

    funnels_list = Funnels.list(site)

    assert [%{name: "Funnel 2", steps_count: 3}, %{name: "Funnel 1", steps_count: 2}] =
             funnels_list
  end

  test "funnels can be evaluated per site within a time range", %{
    site: site,
    steps: [g1, g2, g3 | _]
  } do
    {:ok, funnel} =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        [g1, g2, g3]
      )

    populate_stats(site, [
      build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
      build(:event, name: "Signup", user_id: 123),
      build(:pageview, pathname: "/checkout", user_id: 123),
      build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
      build(:event, name: "Signup", user_id: 666)
    ])

    query = Plausible.Stats.Query.from(site, %{"period" => "all"})

    funnel_data = Funnels.evaluate(query, funnel.id, site)

    assert {:ok,
            %{
              steps: [
                %{
                  label: "Visit /go/to/blog/**",
                  visitors: 2,
                  conversion_rate: "100.00",
                  dropoff: 0
                },
                %{label: "Signup", visitors: 2, conversion_rate: "100.00", dropoff: 0},
                %{label: "Visit /checkout", visitors: 1, conversion_rate: "50.00", dropoff: 1}
              ]
            }} = funnel_data
  end

  test "funnels can be evaluated even where there are no visits yet", %{
    site: site,
    steps: [g1, g2, g3 | _]
  } do
    {:ok, funnel} =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        [g1, g2, g3]
      )

    query = Plausible.Stats.Query.from(site, %{"period" => "all"})

    funnel_data = Funnels.evaluate(query, funnel.id, site)

    assert {:ok,
            %{
              steps: [
                %{
                  label: "Visit /go/to/blog/**",
                  visitors: 0,
                  conversion_rate: "0.00",
                  dropoff: 0
                },
                %{label: "Signup", visitors: 0, conversion_rate: "0.00", dropoff: 0},
                %{label: "Visit /checkout", visitors: 0, conversion_rate: "0.00", dropoff: 0}
              ]
            }} = funnel_data
  end
end