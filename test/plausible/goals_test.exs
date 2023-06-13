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
end
