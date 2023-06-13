defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase

  @user_id 123

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               }
             ]
    end

    test "returns conversions when a direct :is filter on event prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["200"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 1,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               }
             ]
    end

    test "returns conversions when a direct :is_not filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns conversions when a direct :is (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment"
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["500"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => [],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns conversions when a direct :is_not (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "false"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => [],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "garbage filters don't crash the call", %{conn: conn, site: site} do
      filters =
        "{\"source\":\"Direct / None\",\"screen\":\"Desktop\",\"browser\":\"Chrome\",\"os\":\"Mac\",\"os_version\":\"10.15\",\"country\":\"DE\",\"city\":\"2950159\"}%' AND 2*3*8=6*8 AND 'L9sv'!='L9sv%"

      resp =
        conn
        |> get("/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")
        |> json_response(200)

      assert resp == []
    end

    test "returns formatted average and total values for a conversion with revenue value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("200100300.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("300100400.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("0"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 5,
                 "total_conversions" => 5,
                 "prop_names" => [],
                 "conversion_rate" => 100.0,
                 "average_revenue" => %{"short" => "€166.7M", "long" => "€166,733,566.75"},
                 "total_revenue" => %{"short" => "€500.2M", "long" => "€500,200,700.25"}
               }
             ]
    end

    test "returns revenue metrics as nil for non-revenue goals", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.00"),
          revenue_reporting_currency: "EUR"
        )
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 66.7,
                 "average_revenue" => nil,
                 "total_revenue" => nil
               },
               %{
                 "name" => "Payment",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 33.3,
                 "average_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "total_revenue" => %{"long" => "€10.00", "short" => "€10.0"}
               }
             ]
    end

    test "does not return revenue metrics if no revenue goals are returned", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 100.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only the conversion that is filtered for", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 33.3
               }
             ]
    end

    test "returns only the prop name for the property in filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["John"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment", props: %{"logged_in" => "true|(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => ["logged_in"],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns prop_names=[] when goal :member + property filter are applied at the same time",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["John"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Payment|Signup", props: %{"logged_in" => "true|(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => []}] = json_response(conn, 200)
    end

    test "filters out garbage prop_names",
         %{
           conn: conn,
           site: site
         } do
      site =
        site
        |> Plausible.Site.set_allowed_event_props(["author"])
        |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["Valdis"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["Garbage"],
          "meta.value": ["321"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["OnlyGarbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => ["author"]}] = json_response(conn, 200)
    end

    test "filters out garbage prop_names when session filters are applied",
         %{
           conn: conn,
           site: site
         } do
      site =
        site
        |> Plausible.Site.set_allowed_event_props(["author", "logged_in"])
        |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Payment",
          pathname: "/",
          "meta.key": ["author"],
          "meta.value": ["Valdis"]
        ),
        build(:event,
          name: "Payment",
          pathname: "/ignore",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          pathname: "/",
          "meta.key": ["garbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment", entry_page: "/"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => ["author"]}] = json_response(conn, 200)
    end

    test "does not filter any prop names by default (when site.allowed_event_props is nil)",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["Garbage"],
          "meta.value": ["321"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["OnlyGarbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => prop_names}] = json_response(conn, 200)
      assert "Garbage" in prop_names
      assert "OnlyGarbage" in prop_names
    end

    test "can filter by multiple mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by multiple negated mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/another"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /another"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "CTA",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by matches_member filter type on goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /blog**",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Signup",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by not_matches_member filter type on goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})
      insert(:goal, %{site: site, page_path: "/ano**"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /ano**",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "CTA",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal and prop=(none) filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only the conversion that is filtered for", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", user_id: 1),
        build(:pageview, pathname: "/", user_id: 2),
        build(:event, name: "Signup", user_id: 1, "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", user_id: 2)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup", props: %{variant: "(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 50
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/property/:key" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "B",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "returns (none) values in property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "(none)",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "does not return (none) value in property breakdown with is filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns only (none) value in property breakdown with is (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns (none) value in property breakdown with is_not filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with is_not (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0|1"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "returns (none) value in property breakdown with member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "1|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "returns (none) value in property breakdown with not_member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0.01"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|0.01"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 40.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 20.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with not_member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns property breakdown with a pageview goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/variant?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "A",
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "(none)",
                 "total_conversions" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "property breakdown with prop filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1),
        build(:event, user_id: 1, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, user_id: 2),
        build(:event, user_id: 2, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup", props: %{"variant" => "B"}})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 1,
                 "name" => "B",
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "Property breakdown with prop and goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, utm_campaign: "campaignA"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, utm_campaign: "campaignA"),
        build(:event,
          user_id: 2,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          props: %{variant: "A"},
          utm_campaign: "campaignA"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "Property breakdown with goal and source filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, referrer_source: "Google"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, referrer_source: "Google"),
        build(:pageview, user_id: 3, referrer_source: "ignore"),
        build(:event,
          user_id: 3,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          source: "Google"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with glob goals" do
    setup [:create_user, :log_in, :create_site]

    test "returns correct and sorted glob goal counts", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/reg*"})
      insert(:goal, %{site: site, page_path: "/*/register"})
      insert(:goal, %{site: site, page_path: "/billing**/success"})
      insert(:goal, %{site: site, page_path: "/billing*/success"})
      insert(:goal, %{site: site, page_path: "/signup"})
      insert(:goal, %{site: site, page_path: "/signup/*"})
      insert(:goal, %{site: site, page_path: "/signup/**"})
      insert(:goal, %{site: site, page_path: "/*"})
      insert(:goal, %{site: site, page_path: "/**"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/hum",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/register",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/reg",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/billing/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/billing/upgrade/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/2",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/3",
          timestamp: ~N[2019-07-01 23:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-07-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "conversion_rate" => 100.0,
                 "unique_conversions" => 8,
                 "name" => "Visit /**",
                 "total_conversions" => 8,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 37.5,
                 "unique_conversions" => 3,
                 "name" => "Visit /signup/**",
                 "total_conversions" => 3,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 37.5,
                 "unique_conversions" => 3,
                 "name" => "Visit /*",
                 "total_conversions" => 3,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 25.0,
                 "unique_conversions" => 2,
                 "name" => "Visit /billing**/success",
                 "total_conversions" => 2,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 25.0,
                 "unique_conversions" => 2,
                 "name" => "Visit /reg*",
                 "total_conversions" => 2,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /signup/*",
                 "total_conversions" => 1,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /billing*/success",
                 "total_conversions" => 1,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /register",
                 "total_conversions" => 1,
                 "prop_names" => []
               }
             ]
    end

    test "returns prop names when filtered by glob goal", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/register**"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/register",
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/register-success",
          "meta.key": ["logged_in", "author"],
          "meta.value": ["true", "John"],
          timestamp: ~N[2019-07-01 23:00:00]
        )
      ])

      filters = Jason.encode!(%{goal: "Visit /register**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-07-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "conversion_rate" => 100.0,
                 "unique_conversions" => 2,
                 "name" => "Visit /register**",
                 "total_conversions" => 2,
                 "prop_names" => ["logged_in", "author"]
               }
             ]
    end
  end
end
