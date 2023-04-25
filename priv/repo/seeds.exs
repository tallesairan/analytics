# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Plausible.Repo.insert!(%Plausible.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

FunWithFlags.enable(:comparisons)

user = Plausible.Factory.insert(:user, email: "user@plausible.test", password: "plausible")

beginning_of_time = NaiveDateTime.add(NaiveDateTime.utc_now(), -721, :day)

site =
  Plausible.Factory.insert(:site,
    domain: "dummy.site",
    native_stats_start_at: beginning_of_time,
    stats_start_date: NaiveDateTime.to_date(beginning_of_time)
  )

_membership = Plausible.Factory.insert(:site_membership, user: user, site: site, role: :owner)

put_random_time = fn
  date, 0 ->
    current_hour = Time.utc_now().hour
    current_minute = Time.utc_now().minute
    random_time = Time.new!(:rand.uniform(current_hour), :rand.uniform(current_minute - 1), 0)

    date
    |> NaiveDateTime.new!(random_time)
    |> NaiveDateTime.truncate(:second)

  date, _ ->
    random_time = Time.new!(:rand.uniform(23), :rand.uniform(59), 0)

    date
    |> NaiveDateTime.new!(random_time)
    |> NaiveDateTime.truncate(:second)
end

geolocations = [
  [
    country_code: "IT",
    subdivision1_code: "IT-62",
    subdivision2_code: "IT-RM",
    city_geoname_id: 3_169_070
  ],
  [
    country_code: "EE",
    subdivision1_code: "EE-37",
    subdivision2_code: "EE-784",
    city_geoname_id: 588_409
  ],
  [
    country_code: "BR",
    subdivision1_code: "BR-SP",
    subdivision2_code: "",
    city_geoname_id: 3_448_439
  ],
  [
    country_code: "PL",
    subdivision1_code: "PL-14",
    subdivision2_code: "",
    city_geoname_id: 756_135
  ],
  [
    country_code: "DE",
    subdivision1_code: "DE-BE",
    subdivision2_code: "",
    city_geoname_id: 2_950_159
  ],
  [
    country_code: "US",
    subdivision1_code: "US-CA",
    subdivision2_code: "",
    city_geoname_id: 5_391_959
  ],
  []
]

Enum.flat_map(-720..0, fn day_index ->
  date = Date.add(Date.utc_today(), day_index)
  number_of_events = 0..:rand.uniform(500)

  Enum.map(number_of_events, fn _ ->
    geolocation = Enum.random(geolocations)

    [
      site_id: site.id,
      hostname: site.domain,
      timestamp: put_random_time.(date, day_index),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "macOS", "Linux"]),
      operating_system_version: to_string(Enum.random(0..15))
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:pageview, &1))
  end)
end)
|> Plausible.TestUtils.populate_stats()

days_in_current_month = Date.utc_today().day

site =
  Plausible.Site.start_import(
    site,
    NaiveDateTime.to_date(beginning_of_time),
    Date.add(Date.utc_today(), -days_in_current_month - 3),
    "Google Analytics"
  )
  |> Plausible.Repo.update!()

imported_stats_up_to_previous_month =
  Enum.flat_map(-720..(-days_in_current_month - 3), fn day_index ->
    date = Date.add(Date.utc_today(), day_index)
    number_of_events = 0..:rand.uniform(500)

    Enum.flat_map(number_of_events, fn _ ->
      [
        Plausible.Factory.build(:imported_visitors,
          date: date,
          pageviews: Enum.random(1..20),
          visitors: Enum.random(1..20),
          bounces: Enum.random(1..20),
          visits: Enum.random(1..200),
          visit_duration: Enum.random(1..100)
        ),
        Plausible.Factory.build(:imported_sources,
          date: date,
          source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
          visitors: Enum.random(1..20),
          visits: Enum.random(1..200),
          bounces: Enum.random(1..20),
          visit_duration: Enum.random(1..100)
        ),
        Plausible.Factory.build(:imported_pages,
          date: date,
          visitors: Enum.random(1..20),
          pageviews: Enum.random(1..20),
          exits: Enum.random(1..20),
          time_on_page: Enum.random(1..100)
        )
      ]
    end)
  end)

Plausible.TestUtils.populate_stats(site, imported_stats_up_to_previous_month)

Plausible.Site.import_success(site) |> Plausible.Repo.update!()
