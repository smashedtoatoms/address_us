defmodule AddressUS.Parser do
  @moduledoc """
  Parses US Addresses.
  """

  alias AddressUS.Address
  alias AddressUS.Config
  alias AddressUS.Street

  import AddressUS.Util

  @doc """
  Parses a raw address into all of its requisite parts according to USPS
  suggestions for address parsing.
  ## Known Bugs
      1) if street suffix is left off while parsing a full multi-line address,
      it will fail unless there is a comma or newline separating the street
      name from the city.
  ## Examples
      iex> AddressUS.Parser.parse_address("2345 S B Street, Denver, CO 80219")
      %AddressUS.Address{city: "Denver", plus_4: nil, postal: "80219",
      state: "CO", street: %AddressUS.Street{name: "B", pmb: nil,
      post_direction: nil, pre_direction: "S", primary_number: "2345",
      secondary_designator: nil, secondary_value: nil, suffix: "St"}}
  """
  def parse_address(messy_address) when not is_binary(messy_address), do: nil

  def parse_address(messy_address) do
    address = standardize_address(messy_address)
    {postal, plus_4, address_no_postal} = get_postal(address)
    {state, address_no_state} = get_state(address_no_postal)
    {city, address_no_city} = get_city(address_no_state)
    street = parse_address_list(address_no_city)

    %Address{postal: postal, plus_4: plus_4, state: state, city: city, street: street}
  end

  @doc """
  Parses the raw street portion of an address into its requisite parts
  according to USPS suggestions for address parsing.
  ## Examples
      iex> AddressUS.Parser.parse_address_line("2345 S. Beade St")
      %AddressUS.Street{name: "Beade", pmb: nil, post_direction: nil, pre_direction: "S",
      primary_number: "2345", secondary_designator: nil, secondary_value: nil,
      suffix: "St"}
  """
  def parse_address_line(invalid) when not is_binary(invalid), do: nil

  def parse_address_line(messy_address) do
    messy_address
    |> standardize_address
    |> String.split(" ")
    |> Enum.reverse()
    |> parse_address_list
  end

  @doc """
  Parses a csv, but instead of parsing at every comma, it only splits at the
  last one found.  This allows it to handle situations where the first value
  parsed has a comma in it that is not part of what you want to parse.
  ## Example
      iex> AddressUS.Parser.parse_csv("test/test.csv")
      %{"Something Horrible, (The worst place other than Wyoming)" => "SH",
      "Wyoming" => "WY"}
  """
  def parse_csv(nil), do: %{}

  def parse_csv(csv) do
    String.split(File.read!(csv), ~r{\n|\r|\r\n|\n\r})
    |> Stream.map(&String.reverse(&1))
    |> Stream.map(&String.split(&1, ",", parts: 2))
    |> Stream.map(&Enum.reverse(&1))
    |> Stream.map(fn word -> Enum.map(word, &String.reverse(&1)) end)
    |> Stream.map(&List.to_tuple(&1))
    |> Stream.filter(&(tuple_size(&1) == 2))
    |> Enum.to_list()
    |> Enum.into(%{})
  end

  ############################################################################
  ## Parser Functions
  ############################################################################

  # Parses the city name out of the address list and returns
  # {city, leftover_address_list}
  defp get_city(address) when not is_list(address), do: {nil, nil}
  defp get_city([]), do: {nil, nil}
  defp get_city(address), do: get_city(address, address, nil, false)
  defp get_city([], backup, _city, false), do: {nil, backup}

  defp get_city(address, _backup, city, true) do
    {safe_replace(city, ",", ""), address}
  end

  defp get_city(address, backup, city, false) do
    [head | tail] = address

    tail_head =
      case length(tail) > 0 do
        false -> ""
        true -> hd(tail)
      end

    cond do
      is_keyword?(head) && city == nil ->
        get_city(tail, backup, merge_names(city, head), false)

      String.ends_with?(tail_head, ",") ->
        get_city(tail, backup, merge_names(city, head), true)

      head |> safe_starts_with?("#") ->
        get_city(address, backup, city, true)

      Enum.count(clean_hyphenated_street(head)) > 1 ->
        get_city(address, backup, city, true)

      city != nil && !is_keyword?(head) && address != [] &&
          is_possible_suite_number?(tail_head) ->
        get_city(address, backup, city, true)

      city != nil && !is_keyword?(head) && address != [] ->
        get_city(tail, backup, merge_names(city, head), false)

      city != nil && is_keyword?(head) ->
        pre_keyword_white_list = ["SALT", "WEST", "PALM"]

        cond do
          Enum.member?(pre_keyword_white_list, safe_upcase(tail_head)) ->
            get_city(tail, backup, merge_names(city, head), false)

          true ->
            get_city(address, backup, city, true)
        end

      is_keyword?(head) ->
        get_city(address, backup, city, true)

      contains_po_box?(tail) ->
        get_city(tail, backup, head, true)

      tail == [] ->
        get_city(address, backup, city, true)

      get_direction_abbreviation(head) != nil ->
        get_city(tail, backup, merge_names(city, head), false)

      true ->
        get_city(tail, backup, merge_names(city, head), false)
    end
  end

  # Parses the number out of the address list and returns
  # {number, box, possible_secondary_value, possible_secondary_designator}
  defp get_number(address) when not is_list(address) do
    {nil, nil, nil, nil, nil}
  end

  defp get_number([]), do: {nil, nil, nil, nil, nil}

  defp get_number(address) do
    get_number(address, address, nil, nil, nil, nil, false)
  end

  defp get_number(address, _backup, number, box, p_val, p_des, true) do
    n = if number == "", do: nil, else: number
    b = if box == "", do: nil, else: box
    v = if p_val == "", do: nil, else: p_val
    d = if p_des == "", do: nil, else: p_des
    {n, b, v, d, address}
  end

  defp get_number([], backup, _, _, _, _, false) do
    {nil, nil, nil, nil, backup}
  end

  defp get_number(address, backup, number, box, p_val, p_des, false) do
    [head | tail] = address

    {tail_head, tail_tail} =
      case length(tail) do
        0 -> {"", []}
        1 -> {hd(tail), []}
        _ -> {hd(tail), tl(tail)}
      end

    next_is_number =
      if length(tail) == 0 do
        false
      else
        string_is_number_or_fraction?(hd(tail))
      end

    regex = ~r/(\d+)[-\s]*([A-Za-z]+.*)/

    cond do
      address == [] ->
        get_number(backup, backup, number, box, p_val, p_des, true)

      contains_po_box?(address) ->
        number =
          address
          |> Enum.join(" ")
          |> String.split(~r/(?i)BOX\s/)
          |> tl
          |> hd

        get_number([], backup, safe_replace(number, "#", ""), "PO BOX", p_val, p_des, true)

      number == nil && string_is_number_or_fraction?(head) && next_is_number ->
        get_number(tl(tail), backup, head <> " " <> hd(tail), box, p_val, p_des, true)

      Enum.member?(address, "&") ->
        new_address =
          address
          |> Enum.join(" ")
          |> String.split("&")
          |> tl
          |> hd
          |> String.split(" ")

        get_number(new_address, backup, nil, box, p_val, p_des, false)

      number == nil && string_is_number_or_fraction?(head) ->
        alphanumeric = "ABCDFHIJLKMOPQRGTUVXYZ1234567890"

        case safe_contains?(alphanumeric, safe_upcase(tail_head)) do
          false ->
            get_number(tail, backup, head, box, p_val, p_des, true)

          true ->
            get_number(tail_tail, backup, head, box, safe_upcase(tail_head), p_des, true)
        end

      number == nil && string_is_number_or_fraction?(safe_replace(head, regex, "\\1")) ->
        endings = ["ST", "ND", "RD", "TH"]
        new_number = safe_replace(head, regex, "\\1")
        new_value = safe_replace(head, regex, "\\2")

        case Enum.member?(endings, new_value) do
          false ->
            get_number(tail, backup, new_number, box, new_value, p_des, true)

          true ->
            get_number(backup, backup, number, box, new_value, p_des, true)
        end

      number == nil && is_state?(head) ->
        get_number(address, backup, number, box, p_val, p_des, true)

      string_is_hyphenated_address_number?(head) ->
        get_number(tail, backup, head, box, p_val, p_des, true)

      safe_contains?(head, "-") ->
        [h | t] = String.split(head, "-")

        secondary_value =
          case length(t) do
            0 -> nil
            _ -> hd(t)
          end

        get_number(tail, backup, h, box, secondary_value, "Ste", true)

      true ->
        get_number(tail, backup, number, box, p_val, p_des, false)
    end
  end

  # Parses the post direction field out of the address list and returns
  # {post_direction, leftover_address_list}.
  defp get_post_direction(address) when not is_list(address), do: {nil, nil}
  defp get_post_direction([]), do: {nil, nil}
  defp get_post_direction(address), do: get_post_direction(address, nil, false)

  defp get_post_direction(address, post_direction, true) do
    {post_direction, address}
  end

  defp get_post_direction(address, post_direction, false) do
    [head | tail] = address
    direction_value = get_direction_value(head)

    new_direction =
      case post_direction == nil do
        true -> direction_value
        false -> direction_value <> post_direction
      end

    cond do
      get_direction_value(head) == "" ->
        get_post_direction(address, post_direction, true)

      address == [] ->
        get_post_direction(address, new_direction, true)

      true ->
        get_post_direction(tail, new_direction, false)
    end
  end

  # Gets the postal code from an address and returns
  # {zip, zip_plus_4, leftover_address_list}.
  defp get_postal(address) when not is_binary(address), do: {nil, nil, nil}

  defp get_postal(address) do
    reversed_address = Enum.reverse(String.split(address, " "))
    [possible_postal | leftover_address] = reversed_address
    {postal, plus_4} = parse_postal(possible_postal)

    case postal do
      nil -> {nil, nil, reversed_address}
      _ -> {postal, plus_4, leftover_address}
    end
  end

  # Parses the pre direction field out of the address list and returns
  # {pre_direction, leftover_address_list}.
  defp get_pre_direction(address) when not is_list(address), do: {nil, nil}
  defp get_pre_direction([]), do: {nil, nil}
  defp get_pre_direction(address), do: get_pre_direction(address, nil, false)

  defp get_pre_direction(address, _pre_direction, false) do
    [head | tail] = address

    {tail_head, tail_tail} =
      case length(tail) do
        0 -> {"", []}
        1 -> {hd(tail), []}
        _ -> {hd(tail), tl(tail)}
      end

    tail_tail_head = if length(tail_tail) > 0, do: hd(tail_tail), else: nil
    single_word_direction = get_direction_value(head)
    next_is_direction = get_direction_value(tail_head) != ""

    double_word_direction =
      get_direction_value(get_direction_value(head) <> get_direction_value(tail_head))

    tail_tail_head_is_keyword = is_keyword?(tail_tail_head)

    cond do
      single_word_direction != "" && next_is_direction &&
          tail_tail_head_is_keyword ->
        {single_word_direction, tail}

      single_word_direction != "" && next_is_direction &&
          tail_tail_head == nil ->
        {single_word_direction, tail}

      single_word_direction != "" && next_is_direction &&
          !tail_tail_head_is_keyword ->
        {double_word_direction, tail_tail}

      single_word_direction != "" && tail == [] ->
        {nil, address}

      single_word_direction != "" ->
        {single_word_direction, tail}

      true ->
        {nil, address}
    end
  end

  # Parses out the secondary data from an address field and returns
  # {secondary_designator, secondary_value, private_mailbox_number,
  # leftover_address_list}
  defp get_secondary(address) when not is_list(address), do: {nil, nil, nil, []}
  defp get_secondary([]), do: {nil, nil, nil, []}

  defp get_secondary(address) do
    get_secondary(address, address, nil, nil, nil, false)
  end

  defp get_secondary([], backup, _pmb, _designator, _number, false) do
    {nil, nil, nil, backup}
  end

  defp get_secondary(address, _backup, pmb, designator, value, true) do
    [_ | tail] = address

    cond do
      value == nil && pmb != nil ->
        clean_designator = safe_replace(designator, ",", "")
        clean_pmb = safe_replace(pmb, ",", "")
        {clean_designator, nil, clean_pmb, tail}

      true ->
        clean_designator = safe_replace(designator, ",", "")
        clean_value = safe_replace(value, ",", "")
        clean_pmb = safe_replace(pmb, ",", "")
        {clean_designator, clean_value, clean_pmb, address}
    end
  end

  defp get_secondary(address, backup, pmb, designator, value, false) do
    [head | tail] = address

    {tail_head, tail_tail} =
      case length(tail) do
        0 -> {"", []}
        1 -> {hd(tail), []}
        _ -> {hd(tail), tl(tail)}
      end

    units = Config.secondary_units()
    suffixes = Config.street_suffixes()
    directions = Config.directions()

    cond do
      string_is_number?(head) ->
        cond do
          contains_po_box?(tail) || is_state?(tail_head) ->
            get_secondary(tail, backup, pmb, designator, value, false)

          tail_head == '&' ->
            get_secondary(tail_tail, backup, pmb, designator, tail_head <> " " <> head, false)

          safe_starts_with?(value, "&") ->
            get_secondary(tail, backup, pmb, designator, head, false)

          tail_head == "#" ->
            get_secondary(tail_tail, backup, pmb, designator, head, false)

          true ->
            get_secondary(tail, backup, pmb, designator, head, false)
        end

      safe_has_key?(units, title_case(head)) ->
        cond do
          safe_has_key?(suffixes, safe_upcase(value)) ->
            get_secondary(backup, backup, nil, nil, nil, true)

          true ->
            get_secondary(tail, backup, pmb, Map.get(units, head), value, true)
        end

      Map.values(units) |> Enum.member?(title_case(head)) ->
        get_secondary(tail, backup, pmb, title_case(head), value, true)

      safe_starts_with?(head, "#") && !contains_po_box?(address) ->
        all_unit_values = Map.keys(units) ++ Map.values(units)

        cond do
          Enum.member?(all_unit_values, title_case(tail_head)) ->
            secondary_unit =
              cond do
                Map.values(units) |> Enum.member?(title_case(tail_head)) ->
                  title_case(tail_head)

                true ->
                  Map.get(units, title_case(tail_head))
              end

            get_secondary(
              tail_tail,
              backup,
              pmb,
              secondary_unit,
              safe_replace(head, "#", ""),
              true
            )

          true ->
            get_secondary(tail, backup, safe_replace(head, "#", ""), designator, value, false)
        end

      value != nil && designator == nil ->
        all_unit_values = Map.keys(units) ++ Map.values(units)

        cond do
          Enum.member?(all_unit_values, title_case(tail_head)) ->
            secondary_unit =
              cond do
                Map.values(units) |> Enum.member?(title_case(tail_head)) ->
                  title_case(tail_head)

                true ->
                  Map.get(units, title_case(tail_head))
              end

            get_secondary(tail_tail, backup, pmb, secondary_unit, head <> value, true)

          Enum.member?(all_unit_values, title_case(head)) ->
            secondary_unit =
              cond do
                Map.values(units) |> Enum.member?(title_case(head)) ->
                  title_case(head)

                true ->
                  Map.get(units, title_case(head))
              end

            get_secondary(tail, backup, pmb, secondary_unit, value, true)

          true ->
            get_secondary(backup, backup, pmb, designator, nil, true)
        end

      is_possible_suite_number?(tail_head) &&
          (safe_has_key?(units, title_case(tail_head)) ||
             Map.values(units) |> Enum.member?(title_case(tail_head))) ->
        get_secondary(tail, backup, pmb, designator, safe_replace(head, ",", ""), false)

      get_suffix_value(tail_head) != nil && get_suffix_value(head) == nil ->
        cond do
          is_possible_suite_number?(head) &&
              (String.length(tail_tail) < 2 ||
                 String.upcase(hd(tail_tail)) == "STATE") ->
            get_secondary(backup, backup, pmb, designator, value, true)

          Map.values(directions) |> Enum.member?(safe_upcase(head)) ||
              safe_has_key?(directions, title_case(head)) ->
            get_secondary(backup, backup, pmb, designator, value, true)

          true ->
            get_secondary(tail, backup, pmb, designator, value, true)
        end

      tail_head == "&" ->
        get_secondary(tail_tail, backup, pmb, designator, value, false)

      true ->
        get_secondary(backup, backup, pmb, designator, value, true)
    end
  end

  # Parses the state from the address list and returns
  # {state, leftover_address_list}.
  defp get_state(address) when not is_list(address), do: {nil, nil}
  defp get_state([]), do: {nil, nil}
  defp get_state(address), do: get_state(address, address, nil, 5)
  defp get_state([], backup, _, count) when count > 0, do: {nil, backup}

  defp get_state(address, _, state, 0) do
    {safe_replace(state, ",", ""), address}
  end

  defp get_state(address, address_backup, state, count) do
    states = Config.states()
    [head | tail] = address
    state_to_evaluate = safe_replace(merge_names(state, head), ",", "")

    cond do
      count == 5 && Enum.member?(Map.values(states), head) ->
        get_state(tail, address_backup, head, 0)

      safe_has_key?(states, state_to_evaluate) ->
        get_state(tail, address_backup, Map.get(states, state_to_evaluate), 0)

      Enum.member?(Map.values(states), safe_upcase(state_to_evaluate)) ->
        get_state(tail, address_backup, safe_upcase(state_to_evaluate), 0)

      count == 1 ->
        get_state(address_backup, address_backup, nil, 0)

      true ->
        get_state(tail, address_backup, state_to_evaluate, count - 1)
    end
  end

  # Parses the street out of the address list and returns the street name as a
  # string.
  defp get_street(address) when not is_list(address), do: nil
  defp get_street([]), do: nil
  defp get_street(address), do: get_street(address, nil, false)
  defp get_street([], street, false), do: get_street([], street, true)

  defp get_street(_address, street, true) do
    corner_case_street_names = %{"PGA" => "PGA", "ROUTE" => "Route", "RT" => "Route"}
    filtered_street = safe_upcase(street) |> safe_replace(~r/\s(\d+)/, "")
    directions = Config.directions()
    rev_directions = Config.reversed_directions()

    cond do
      safe_has_key?(corner_case_street_names, filtered_street) ->
        street_name =
          Map.get(corner_case_street_names, filtered_street)
          |> safe_replace(~r/\s(\d+)/, "")

        street_number = " " <> safe_replace(street, ~r/[a-zA-Z\s]+/, "")
        (street_name <> street_number) |> safe_replace(~r/\s$/, "")

      Enum.member?(
        Map.keys(directions) ++ Map.values(directions),
        title_case(street)
      ) ->
        cond do
          Map.has_key?(directions, title_case(street)) ->
            title_case(street)

          true ->
            Map.get(rev_directions, String.upcase(street))
        end

      true ->
        street
    end
  end

  defp get_street(address, street, false) do
    [head | tail] = address

    cond do
      head == "&" || head == "AND" ->
        get_street(tail, nil, false)

      length(address) == 0 ->
        directions = Config.directions()
        rev_directions = Config.reversed_directions()
        keys = Map.keys(directions)
        values = Map.values(directions)
        street_is_direction = (keys ++ values) |> Enum.member?(head)

        street_name =
          cond do
            street_is_direction ->
              cond do
                Map.has_key?(directions, title_case(head)) ->
                  Map.get(rev_directions, Map.get(directions, title_case(head)))

                true ->
                  Map.get(rev_directions, String.upcase(head))
              end

            true ->
              street
          end

        get_street(address, street_name, true)

      length(clean_hyphenated_street(head)) > 1 ->
        cond do
          is_keyword?(street) ->
            get_street(tail, street <> " " <> head, false)

          true ->
            get_street(clean_hyphenated_street(head) ++ tail, street, false)
        end

      true ->
        new_address =
          cond do
            street == nil -> title_case(head)
            true -> street <> " " <> title_case(head)
          end

        get_street(tail, new_address, false)
    end
  end

  # Parses the suffix out of the address list and returns
  # {suffix, leftover_address_list}
  defp get_suffix(address) when not is_list(address), do: {nil, nil}
  defp get_suffix([]), do: {nil, nil}
  defp get_suffix(address), do: get_suffix(address, nil, false)
  defp get_suffix(address, suffix, true), do: {suffix, address}

  defp get_suffix(address, _, false) do
    [head | tail] = address
    new_suffix = get_suffix_value(head)

    cond do
      Enum.count(clean_hyphenated_street(head)) > 1 ->
        get_suffix(address, nil, true)

      new_suffix != nil ->
        get_suffix(tail, new_suffix, true)

      true ->
        get_suffix(address, nil, true)
    end
  end

  # Parses an address list for all of the requisite address parts and returns
  # a Street module.
  # p_val = possible secondary value
  # p_des = possible secondary designator
  defp parse_address_list(address) when not is_list(address), do: nil
  defp parse_address_list([]), do: nil
  defp parse_address_list([""]), do: nil

  defp parse_address_list(address) do
    cleaned_address = Enum.map(address, &safe_replace(&1, ",", ""))
    {designator, value, pmb, address_no_secondary} = get_secondary(cleaned_address)
    {post_direction, address_no_secondary_direction} = get_post_direction(address_no_secondary)
    {suffix, address_no_suffix} = get_suffix(address_no_secondary_direction)
    reversed_address_remnants = Enum.reverse(address_no_suffix)

    {primary_number, box, p_val, p_des, address_no_number} = get_number(reversed_address_remnants)

    {pre_direction, address_no_pre_direction} = get_pre_direction(address_no_number)
    street_name = get_street(address_no_pre_direction)

    name =
      case street_name == nil && !(box == nil) do
        true -> box
        false -> street_name
      end

    {final_name, final_secondary_val} =
      cond do
        name == nil ->
          cond do
            p_val != nil && p_des == nil -> {p_val, nil}
            true -> {nil, p_val}
          end

        true ->
          {name, p_val}
      end

    final_secondary_designator =
      cond do
        designator == nil && p_des != nil -> p_des
        true -> designator
      end

    final_secondary_value =
      cond do
        p_val == nil ->
          value

        true ->
          cond do
            value == nil -> final_secondary_val
            true -> value
          end
      end

    %Street{
      secondary_designator: final_secondary_designator,
      post_direction: post_direction,
      pre_direction: pre_direction,
      secondary_value: final_secondary_value,
      pmb: pmb,
      suffix: suffix,
      primary_number: primary_number,
      name: final_name
    }
  end

  # Parses postal value passed to it and returns {zip_code, zip_plus_4}
  defp parse_postal(postal) when not is_binary(postal), do: {nil, nil}

  defp parse_postal(postal) do
    cond do
      Regex.match?(~r/^\d?\d?\d?\d?\d-\d?\d?\d?\d$/, postal) ->
        [dirty_zip | tail] = String.split(postal, "-")
        [dirty_plus4 | _] = tail
        zip = dirty_zip |> safe_replace(",", "") |> String.pad_leading(5, "0")
        plus4 = dirty_plus4 |> safe_replace(",", "") |> String.pad_leading(4, "0")
        {zip, plus4}

      Regex.match?(~r/^\d{9}$/, postal) ->
        String.split_at(postal, 5)

      Regex.match?(~r/^\d?\d?\d?\d?\d$/, postal) ->
        clean_postal = postal |> String.pad_leading(5, "0") |> safe_replace(",", "")
        {clean_postal, nil}

      true ->
        {nil, nil}
    end
  end

  ############################################################################
  ## Helper Functions
  ############################################################################

  # Cleans up hyphenated street values by removing the hyphen and returing the
  # values or the appropriate USPS abbreviations for said values in a list.
  defp clean_hyphenated_street(value) when not is_binary(value), do: [value]

  defp clean_hyphenated_street(value) do
    case value |> String.match?(~r/-/) do
      true ->
        suffix_data = Config.street_suffixes()
        suffixes = Map.keys(suffix_data) ++ Map.values(suffix_data)
        values = value |> String.split("-")
        truths = Enum.map(values, &Enum.member?(suffixes, safe_upcase(&1)))

        new_values =
          Enum.map(values, fn v ->
            case safe_has_key?(suffix_data, safe_upcase(v)) do
              true -> title_case(Map.get(suffix_data, safe_upcase(v)))
              false -> title_case(v)
            end
          end)

        case Enum.any?(truths) do
          true -> new_values
          false -> [value]
        end

      false ->
        [value]
    end
  end

  # Gets direction abbreviation string.
  defp get_direction_abbreviation(value) when not is_binary(value), do: nil

  defp get_direction_abbreviation(value) do
    val = title_case(value)
    directions = Config.directions()

    cond do
      safe_has_key?(directions, val) -> Map.get(directions, val)
      Map.values(directions) |> Enum.member?(val) -> safe_upcase(val)
      true -> nil
    end
  end

  # Returns the appropriate direction value if a direction is found.
  defp get_direction_value(value) when not is_binary(value), do: ""

  defp get_direction_value(value) do
    directions = Config.directions()
    clean_value = title_case(value)

    cond do
      safe_has_key?(directions, clean_value) ->
        Map.get(directions, clean_value)

      Map.values(directions) |> Enum.member?(safe_upcase(clean_value)) ->
        safe_upcase(clean_value)

      true ->
        ""
    end
  end

  # Returns the appropriate suffix value if one is found.
  defp get_suffix_value(value) when not is_binary(value), do: nil

  defp get_suffix_value(value) do
    suffixes = Config.street_suffixes()
    cleaned_value = title_case(value)
    capitalized_keys = Map.keys(suffixes) |> Enum.map(&title_case(&1))
    capitalized_values = Map.values(suffixes) |> Enum.map(&title_case(&1))
    suffix_values = capitalized_keys ++ capitalized_values

    cond do
      Enum.member?(suffix_values, cleaned_value) ->
        case safe_has_key?(suffixes, safe_upcase(cleaned_value)) do
          true -> Map.get(suffixes, safe_upcase(cleaned_value))
          false -> cleaned_value
        end

      true ->
        nil
    end
  end

  # Merges two strings into a single string and keeps the spacing correct.
  defp merge_names(nil, name2), do: name2

  defp merge_names(name1, name2) do
    direction1 = get_direction_abbreviation(hd(String.split(name1, " ")))
    direction2 = get_direction_abbreviation(name2)

    cond do
      direction1 != nil && direction2 != nil -> name2 <> name1
      name1 == nil -> name2
      true -> name2 <> " " <> name1
    end
  end

  # Standardizes the spacing around the commas, periods, and newlines and then
  # deletes the periods per the best practices outlined by the USPS.  It also
  # replaces newline characters with commas, and replaces '# <value>' with
  # '#<value>' and then returns the string.
  defp standardize_address(address) when not is_binary(address), do: nil

  defp standardize_address(address) do
    address
    |> String.trim_trailing()
    |> safe_replace(~r/ United States$/, "")
    |> safe_replace(~r/ UNITED STATES$/, "")
    |> safe_replace(~r/ US$/, "")
    |> safe_replace(~r/US$/, "")
    |> safe_replace(~r/, USA$/, "")
    |> safe_replace(~r/ USA$/, "")
    |> safe_replace(~r/USA$/, "")
    |> safe_replace(~r/\(SEC\)/, "")
    |> safe_replace(~r/U\.S\./, "US")
    |> safe_replace(~r/\sM L King\s/, " Martin Luther King ")
    |> safe_replace(~r/\sMLK\s/, " Martin Luther King ")
    |> safe_replace(~r/\sMLKING\s/, " Martin Luther King ")
    |> safe_replace(~r/\sML KING\s/, " Martin Luther King ")
    |> safe_replace(~r/(.+)\(/, "\\1 (")
    |> safe_replace(~r/\)(.+)/, ") \\1")
    |> safe_replace(~r/\((.+)\)/, "\\1")
    |> safe_replace(~r/(?i)\sAND\s/, "&")
    |> safe_replace(~r/(?i)\sI\.E\.\s/, "")
    |> safe_replace(~r/(?i)\sET\sAL\s/, "")
    |> safe_replace(~r/(?i)\sIN\sCARE\sOF\s/, "")
    |> safe_replace(~r/(?i)\sCARE\sOF\s/, "")
    |> safe_replace(~r/(?i)\sBY\s/, "")
    |> safe_replace(~r/(?i)\sFOR\s/, "")
    |> safe_replace(~r/(?i)\sALSO\s/, "")
    |> safe_replace(~r/(?i)\sATTENTION\s/, "")
    |> safe_replace(~r/(?i)\sATTN\s/, "")
    |> safe_replace(~r/(?i)\ss#\ss(\S)/, " #\\1")
    |> safe_replace(~r/(?i)P O BOX/, "PO BOX")
    |> safe_replace(~r/(?i)US (\d+)/, "US Hwy \\1")
    |> safe_replace(~r/(?i)(\d+) Hwy (\d+)/, "\\1 Highway \\2")
    |> safe_replace(~r/(.+)#/, "\\1 #")
    |> safe_replace(~r/\n/, ", ")
    |> safe_replace(~r/\t/, " ")
    |> safe_replace(~r/\s+/, " ")
    |> safe_replace(~r/,(\S)/, ", \\1")
    |> safe_replace(~r/\s,(\S)/, ", \\1")
    |> safe_replace(~r/(\S),\s/, "\\1, ")
    |> safe_replace(~r/\.(\S)/, ". \\1")
    |> safe_replace(~r/\s\.\s/, ". ")
    |> safe_replace(~r/\s\.(\S)/, ". \\1")
    |> safe_replace(~r/(\S)\.\s/, "\\1. ")
    |> safe_replace(~r/\./, "")
    |> safe_replace(~r/\s,\s/, ", ")
  end

  # Determines if address list contains a PO Box.
  defp contains_po_box?(address) when not is_list(address), do: false
  defp contains_po_box?([]), do: false

  defp contains_po_box?(address) do
    [head | _] = address
    full_address = address |> Enum.join(" ") |> safe_upcase
    !is_keyword?(head) && String.match?(full_address, ~r/BOX/)
  end

  # Determines if a value is a number, fraction, or postal keyword.
  defp is_keyword?(value) when not is_binary(value), do: false

  defp is_keyword?(value) do
    word = title_case(value)
    units = Config.secondary_units()
    suffixes = Config.street_suffixes()
    keywords1 = Map.keys(units) ++ Map.values(units) ++ Map.values(suffixes)
    keywords2 = Map.keys(suffixes)

    cond do
      string_is_number_or_fraction?(word) -> true
      Enum.member?(keywords1, word) -> true
      Enum.member?(keywords2, safe_upcase(word)) -> true
      true -> false
    end
  end

  # Detects if a string is a state or not.
  defp is_state?(value) when not is_binary(value), do: false

  defp is_state?(value) do
    state = title_case(value)
    states = Config.states()

    cond do
      safe_has_key?(states, state) -> true
      Map.values(states) |> Enum.member?(safe_upcase(state)) -> true
      true -> false
    end
  end

  # Determines if a value is a possible Suite value.
  defp is_possible_suite_number?(value) do
    units = Config.secondary_units()
    values = Map.values(units) |> Enum.map(&String.downcase(&1))
    keys = Map.keys(units) |> Enum.map(&String.downcase(&1))
    (values ++ keys) |> Enum.member?(String.downcase(value))
  end

  # Determines if string can be cleanly converted into a number.
  defp string_is_number?(value) when is_number(value), do: true
  defp string_is_number?(value) when not is_binary(value), do: false

  defp string_is_number?(value) do
    is_integer =
      case Integer.parse(value) do
        :error -> false
        {_, ""} -> true
        {_, _} -> false
      end

    is_float =
      case Float.parse(value) do
        :error -> false
        {_, ""} -> true
        {_, _} -> false
      end

    cond do
      is_integer -> true
      is_float -> true
      true -> false
    end
  end

  # Determines if value is a number or a fraction.
  defp string_is_number_or_fraction?(value) when not is_binary(value), do: false

  defp string_is_number_or_fraction?(value) do
    cond do
      string_is_number?(value) ->
        true

      String.match?(value, ~r/\//) ->
        values = String.split(value, "/")

        case Enum.count(values) do
          2 -> Enum.all?(values, &string_is_number?(&1))
          _ -> false
        end

      true ->
        false
    end
  end

  # Determines if a string represents a pair of numbers separated by a hyphen, where the first
  # number has between one and three digits.
  defp string_is_hyphenated_address_number?(value) when not is_binary(value), do: false

  defp string_is_hyphenated_address_number?(value) do
    regex = ~r/^\d\d?\d?-\d+$/
    String.match?(value, regex)
  end
end
