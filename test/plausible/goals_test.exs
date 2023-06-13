defmodule Plausible.GoalsTest do
  use Plausible.DataCase

  alias Plausible.Goals

  test "create/2 trims input" do
    site = insert(:site)
    {:ok, goal} = Goals.create(site, %{"page_path" => "/foo bar "})
    assert goal.page_path == "/foo bar"

    {:ok, goal} = Goals.create(site, %{"event_name" => "  some event name   "})
    assert goal.event_name == "some event name"
  end

  test "create/2 validates goal name is at most 120 chars" do
    site = insert(:site)
    assert {:error, changeset} = Goals.create(site, %{"event_name" => String.duplicate("a", 130)})
    assert {"should be at most %{count} character(s)", _} = changeset.errors[:event_name]
  end

  test "for_site2 returns trimmed input even if it was saved with trailing whitespace" do
    site = insert(:site)
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    goals = Goals.for_site(site)

    assert [%{page_path: "/Signup"}, %{event_name: "Signup"}] = goals
  end

  test "goals are present after domain change" do
    site = insert(:site)
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    {:ok, site} = Plausible.Site.Domain.change(site, "goals.example.com")

    assert [_, _] = Goals.for_site(site)
  end

  test "goals are removed when site is deleted" do
    site = insert(:site)
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    Plausible.Site.Removal.run(site.domain)

    assert [] = Goals.for_site(site)
  end

  test "goals can be deleted" do
    site = insert(:site)
    goal = insert(:goal, %{site: site, event_name: " Signup "})
    :ok = Goals.delete(goal.id, site)
    assert [] = Goals.for_site(site)
  end

  test "goals can be fetched with funnel count preloaded" do
    site = insert(:site)

    goals =
      Enum.map(1..4, fn i ->
        {:ok, g} = Goals.create(site, %{"page_path" => "/#{i}"})
        g
      end)

    {:ok, %{id: funnel_id1}} =
      Plausible.Funnels.create(
        site,
        "Funnel1",
        [
          %{"goal_id" => Enum.at(goals, 1).id},
          %{"goal_id" => Enum.at(goals, 2).id},
          %{"goal_id" => Enum.at(goals, 3).id}
        ]
      )

    {:ok, %{id: funnel_id2}} =
      Plausible.Funnels.create(
        site,
        "Funnel2",
        [
          %{"goal_id" => Enum.at(goals, 1).id},
          %{"goal_id" => Enum.at(goals, 3).id}
        ]
      )

    assert [goal, _, _, _] = Goals.for_site(site, preload_funnels?: false)
    assert %Ecto.Association.NotLoaded{} = goal.funnels

    assert [goal, _, _, _] = Goals.for_site(site, preload_funnels?: true)
    assert [%{id: ^funnel_id1}, %{id: ^funnel_id2}] = goal.funnels
  end

  test "deleting goals with funnels triggers funnel reduction" do
    site = insert(:site)
    {:ok, g1} = Goals.create(site, %{"page_path" => "/1"})
    {:ok, g2} = Goals.create(site, %{"page_path" => "/2"})
    {:ok, g3} = Goals.create(site, %{"page_path" => "/3"})

    {:ok, _} =
      Plausible.Funnels.create(
        site,
        "Funnel",
        [
          %{"goal_id" => g1.id},
          %{"goal_id" => g2.id},
          %{"goal_id" => g3.id}
        ]
      )

    :ok = Goals.delete(g1.id, site)
  end
end
