defmodule Address do
  @moduledoc """
  Container for the struct that contains the Address information.
  """

  @doc """
  Struct containing Address information.
  """
  defstruct city: nil, plus_4: nil, street: nil, state: nil, postal: nil
end

defmodule Street do
  @moduledoc """
  Container for the struct that contains the Street information for an address.
  """

  @doc """
  Struct containing the Street information.
  """
  defstruct name: nil, pmb: nil, pre_direction: nil, primary_number: nil, 
    post_direction: nil, secondary_designator: nil, secondary_value: nil,
    suffix: nil
end

defmodule AddressUS.Parser do
  @moduledoc """
  Parses US Addresses.
  """

  @doc """
  Parses a raw address into all of its requisite parts according to USPS
  suggestions for address parsing.
  ## Known Bugs
      1) if street suffix is left off while parsing a full multi-line address, 
      it will fail unless there is a comma or newline separating the street
      name from the city.
  ## Examples
      iex> AddressUS.Parser.parse_address("2345 S B Street, Denver, CO 80219")
      %Address{city: "Denver", plus_4: nil, postal: "80219", 
      state: "CO", street: %Street{name: "B", pmb: nil, 
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

    %Address{postal: postal, plus_4: plus_4, state: state, 
      city: city, street: street}
  end

  @doc """
  Parses the raw street portion of an address into its requisite parts
  according to USPS suggestions for address parsing.
  ## Examples
      iex> AddressUS.Parser.parse_address_line("2345 S. Meade St")
      %Street{name: "Meade", pmb: nil, post_direction: nil, pre_direction: "S", 
      primary_number: "2345", secondary_designator: nil, secondary_value: nil, 
      suffix: "St"}
  """
  def parse_address_line(invalid) when not is_binary(invalid), do: nil
  def parse_address_line(messy_address) do
    messy_address 
      |> standardize_address 
      |> String.split(" ") 
      |> Enum.reverse 
      |> parse_address_list
  end

  @doc """
  Removes non-numeric characters from the phone number and then returns the
  integer.
  ## Examples
      iex> AddressUS.Parser.clean_phone_number("(503) 310-7802")
      5033107802
  """
  def clean_phone_number(nil), do: nil
  def clean_phone_number(phone) do
    {phone_integer, _} = phone
      |> safe_replace(~r/\s+/, "")
      |> safe_replace("+1", "")
      |> safe_replace("-", "")
      |> safe_replace("(", "")
      |> safe_replace(")", "")
      |> Integer.parse
    phone_integer
  end

  @doc """
  Removes country code and associated punctuation from the phone number.
  ## Examples
      iex> AddressUS.Parser.filter_country_code("+1 503-310-7802")
      "503-310-7802"
      iex> AddressUS.Parser.filter_country_code("+1 (503) 310-7802")
      "(503) 310-7802"
      iex> AddressUS.Parser.filter_country_code("+1-503-310-7802")
      "503-310-7802"
      iex> AddressUS.Parser.filter_country_code("1-503-310-7802")
      "503-310-7802"
  """
  def filter_country_code(nil), do: nil
  def filter_country_code(phone) do
    phone
      |> safe_replace(~r/^1\s+|^1-|^\+1\s+|^\+1-/, "")
      |> safe_replace(~r/^1\(|^1\s+\(/, "(")
      |> safe_replace(~r/\)(\d)/, ") \\1")
  end

  @doc """
  Abbreviates the state provided.
  ## Example
      iex> AddressUS.Parser.abbreviate_state("Wyoming")
      "WY"
      iex> AddressUS.Parser.abbreviate_state("wyoming")
      "WY"
      iex> AddressUS.Parser.abbreviate_state("Wyomin")
      "Wyomin"
      iex> AddressUS.Parser.abbreviate_state(nil)
      nil
  """
  def abbreviate_state(nil), do: nil
  def abbreviate_state(raw_state) do
    state = title_case(raw_state)
    states = Application.get_env(:parsing, :states)
    cond do
      Map.has_key?(states, state) == true -> 
        Map.get(states, state)
      Enum.member?(Map.values(states), String.upcase(state)) == true -> 
        String.upcase(state)
      true -> 
        state
    end
  end

  @doc """
  Converts the country to the 2 digit ISO country code.  "US" is default.
  ## Example
      iex> AddressUS.Parser.get_country_code(nil)
      "US"
      iex> AddressUS.Parser.get_country_code("Afghanistan")
      "AF"
      iex> AddressUS.Parser.get_country_code("AF")
      "AF"
  """
  def get_country_code(nil), do: "US"
  def get_country_code(country_name) do
    codes = Application.get_env(:parsing, :countries)
    country = String.upcase(country_name)
    case Enum.member?(Map.values(codes), country) do
      true -> country
      false -> Map.get(codes, country, country_name)
    end
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
      |> Stream.map(&(String.reverse(&1)))
      |> Stream.map(&(String.split(&1, ",", parts: 2)))
      |> Stream.map(&(Enum.reverse(&1)))
      |> Stream.map(fn(word) -> Enum.map(word, &(String.reverse(&1))) end)
      |> Stream.map(&(List.to_tuple(&1)))
      |> Stream.filter(&(tuple_size(&1) == 2))
      |> Enum.to_list
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
    [head|tail] = address
    tail_head = if length(tail) > 0, do: hd(tail), else: ""
    cond do
      is_keyword?(head) && city == nil -> 
        get_city(tail, backup, merge_names(city, head), false)
      String.ends_with?(tail_head, ",") ->
        get_city(tail, backup, merge_names(city, head), true)
      head |> String.starts_with?("#") -> 
        get_city(address, backup, city, true)
      Enum.count(clean_hyphenated_street(head)) > 1 ->
        get_city(address, backup, city, true)
      city != nil && !is_keyword?(head) && address != [] 
          && is_possible_suite_number?(head) ->
        get_city(address, backup, city, true)
      city != nil && !is_keyword?(head) && address != [] ->
        get_city(tail, backup, merge_names(city, head), false)
      city != nil && is_keyword?(head) ->
        get_city(address, backup, city, true)
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
  # {number, leftover_address_list}
  defp get_number(address) when not is_list(address), do: {nil, nil, nil}
  defp get_number([]), do: {nil, nil, nil}
  defp get_number(address), do: get_number(address, address, nil, nil, false)
  defp get_number(address, _backup, number, box, true) do
    {number, box, address}
  end
  defp get_number([], backup, _, _, false), do: {nil, nil, backup}
  defp get_number(address, backup, number, box, false) do
    [head|tail] = address
    next_is_number = if length(tail) == 0 do 
      false
    else
      string_is_number_or_fraction?(hd(tail))
    end
    cond do
      address == [] -> get_number(backup, backup, number, box, true)
      contains_po_box?(address) ->
        number = address 
          |> Enum.join(" ") 
          |> String.split(~r/(?i)BOX\s/)
          |> tl
          |> hd
        get_number([], backup, String.replace(number, "#", ""), "PO BOX", true)
      number == nil && string_is_number_or_fraction?(head) && next_is_number ->
        get_number(tl(tail), backup, head <> " " <> hd(tail), box, true)
      Enum.member?(address, "&") ->
        new_address = address
          |> Enum.join(" ")
          |> String.split("&")
          |> tl
          |> hd
          |> String.split(" ")
        get_number(new_address, backup, nil, box, false)
      number == nil && string_is_number_or_fraction?(head) ->
        get_number(tail, backup, head, box, true)
      number == nil && string_is_number_or_fraction?(
          safe_replace(head, ~r/(\d+)[A-Za-z]/, "\\1")) ->
        get_number(tail, backup, safe_replace(head, ~r/(\d+)[A-Za-z]/, "\\1"), 
          box, true)
      number == nil && is_state?(head) ->
        get_number(address, backup, number, box, true)
      true ->
        get_number(tail, backup, number, box, false)
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
    [head|tail] = address
    direction_value = get_direction_value(head)
    new_direction = case post_direction == nil do
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
    [possible_postal|leftover_address] = reversed_address
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
    [head|tail] = address
    {tail_head, tail_tail} = case length(tail) do
      0 -> {"", []}
      1 -> {hd(tail), []}
      _ -> {hd(tail), tl(tail)}
    end

    tail_tail_head = if length(tail_tail) > 0, do: hd(tail_tail), else: nil
    single_word_direction = get_direction_value(head)
    next_is_direction = get_direction_value(tail_head) != ""
    double_word_direction = get_direction_value(
      get_direction_value(head) <> get_direction_value(tail_head)
    )
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
    [_|tail] = address
    cond do
      value == nil && pmb != nil -> 
        clean_designator = safe_replace(designator, ",", "")
        clean_pmb = safe_replace(pmb, ",", "")
        {clean_designator, nil, clean_pmb, tail}
      true -> 
        clean_designator = safe_replace(designator, ",", "")
        clean_number = safe_replace(value, ",", "")
        clean_pmb = safe_replace(pmb, ",", "")
        {clean_designator, clean_number, clean_pmb, address}
    end
  end
  defp get_secondary(address, backup, pmb, designator, value, false) do
    [head|tail] = address
    tail_head = if length(tail) > 0, do: hd(tail), else: nil
    units = Application.get_env(:parsing, :secondary_units)
    cond do
      string_is_number?(head) ->
        cond do
          contains_po_box?(tail) || is_state?(tail_head)-> 
            get_secondary(tail, backup, pmb, designator, value, false)
          true -> 
            get_secondary(tail, backup, pmb, designator, head, false)
        end
      Map.has_key?(units, title_case(head)) ->
        get_secondary(tail, backup, pmb, Map.get(units, title_case(head)), 
          value, true)
      Map.values(units) |> Enum.member?(title_case(head)) ->
        get_secondary(tail, backup, pmb, title_case(head), value, true)
      String.starts_with?(head, "#") && !contains_po_box?(address) ->
        get_secondary(tail, backup, safe_replace(head, "#", ""), designator, 
          value, false)
      value != nil && designator == nil ->
        get_secondary(backup, backup, pmb, designator, nil, true)
      is_possible_suite_number?(head) && (
          Map.has_key?(units, title_case(tail_head)) ||
          Map.values(units) |> Enum.member?(title_case(tail_head))) ->
        get_secondary(tail, backup, pmb, designator, 
          safe_replace(head, ",", ""), false)
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
    states = Application.get_env(:parsing, :states)
    [head|tail] = address
    state_to_evaluate = safe_replace(merge_names(state, head), ",", "")
    cond do
      count == 5 && Enum.member?(Map.values(states), head) ->
        get_state(tail, address_backup, head, 0)
      Map.has_key?(states, state_to_evaluate) ->
        get_state(tail, address_backup, Map.get(states, state_to_evaluate), 0)
      Enum.member?(Map.values(states), String.upcase(state_to_evaluate)) ->
        get_state(tail, address_backup, String.upcase(state_to_evaluate), 0)
      count == 1 ->
        get_state(address_backup, address_backup, nil, 0)
      true -> 
        get_state(tail, address_backup, state_to_evaluate, count-1)
    end
  end

  # Parses the street out of the address list and returns the street name as a
  # string.
  defp get_street(address) when not is_list(address), do: nil
  defp get_street([]), do: nil
  defp get_street(address), do: get_street(address, nil, false)
  defp get_street([], street, _) do 
    directions = Application.get_env(:parsing, :reversed_directions)
    has_key = Map.has_key?(directions, street)
    if has_key, do: Map.get(directions, street), else: street
  end
  defp get_street(_address, street, true) do
    directions = Application.get_env(:parsing, :reversed_directions)
    has_key = Map.has_key?(directions, street)
    if has_key, do: Map.get(directions, street), else: street
  end
  defp get_street(address, street, false) do
    [head|tail] = address
    cond do
      head == "&" || head == "AND" ->
        get_street(tail, nil, false)
      length(address) == 0 ->
        directions = Application.get_env(:parsing, :reversed_directions)
        has_key = Map.has_key?(directions, street)
        street_name = if has_key, do: Map.get(directions, street), else: street
        get_street(address, street_name, true)
      length(clean_hyphenated_street(head)) > 1 ->
        get_street(clean_hyphenated_street(head) ++ tail, street, false)
      true ->
        new_address = if street == nil, do: head, else: street <> " " <> head
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
    [head|tail] = address
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
  defp parse_address_list(address) when not is_list(address), do: nil
  defp parse_address_list([]), do: nil
  defp parse_address_list([""]), do: nil
  defp parse_address_list(address) do
    cleaned_address = Enum.map(address, &(safe_replace(&1, ",", "")))
    {secondary_designator, secondary_value, pmb, address_no_secondary} = 
      get_secondary(cleaned_address)
    {post_direction, address_no_secondary_direction} = 
      get_post_direction(address_no_secondary)
    {suffix, address_no_suffix} = 
      get_suffix(address_no_secondary_direction)
    reversed_address_remnants = 
      Enum.reverse(address_no_suffix)
    {primary_number, box, address_no_number} = 
      get_number(reversed_address_remnants)
    {pre_direction, address_no_pre_direction} =
      get_pre_direction(address_no_number)
    street_name = get_street(address_no_pre_direction)
    name = case street_name == nil && !(box == nil) do
      true -> box
      false -> street_name
    end

    %Street{secondary_designator: secondary_designator, 
    post_direction: post_direction, pre_direction: pre_direction,
    secondary_value: secondary_value,  pmb: pmb, suffix: suffix, 
    primary_number: primary_number, name: name}
  end

  # Parses postal value passed to it and returns {zip_code, zip_plus_4}
  defp parse_postal(postal) when not is_binary(postal), do: {nil, nil}
  defp parse_postal(postal) do
    cond do
      Regex.match?(~r/^\d?\d?\d?\d?\d-\d?\d?\d?\d$/, postal) ->
        [dirty_zip|tail] = String.split(postal, "-")
        [dirty_plus4|_] = tail
        zip = dirty_zip |> safe_replace(",", "") |> String.rjust(5, ?0)
        plus4 = dirty_plus4 |> safe_replace(",", "") |> String.rjust(4, ?0)
        {zip, plus4}
      Regex.match?(~r/^\d?\d?\d?\d?\d$/, postal) ->
        clean_postal = postal |> String.rjust(5, ?0) |> safe_replace(",", "")
        {clean_postal , nil}
      true -> {nil, nil}
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
        suffix_data = Application.get_env(:parsing, :street_suffixes)
        suffixes = Map.keys(suffix_data) ++ Map.values(suffix_data)
        values = value |> String.split("-")
        truths = Enum.map(values, &(Enum.member?(suffixes, String.upcase(&1))))
        new_values = Enum.map(values, fn(v) -> 
          case Map.has_key?(suffix_data, String.upcase(v)) do
            true -> title_case(Map.get(suffix_data, String.upcase(v)))
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
    directions = Application.get_env(:parsing, :directions)
    cond do
      Map.has_key?(directions, val) -> Map.get(directions, val)
      Map.values(directions) |> Enum.member?(val) -> String.upcase(val)
      true -> nil
    end
  end

  # Returns the appropriate direction value if a direction is found.
  defp get_direction_value(value) when not is_binary(value), do: ""
  defp get_direction_value(value) do
    directions = Application.get_env(:parsing, :directions)
    clean_value = title_case(value)
    cond do
      Map.has_key?(directions, clean_value) ->
        Map.get(directions, clean_value)
      Map.values(directions) |> Enum.member?(String.upcase(clean_value)) ->
        String.upcase(clean_value)
      true -> ""
    end
  end

  # Returns the appropriate suffix value if one is found.
  defp get_suffix_value(value) when not is_binary(value), do: nil
  defp get_suffix_value(value) do
    suffixes = Application.get_env(:parsing, :street_suffixes)
    cleaned_value = title_case(value)
    capitalized_keys = Map.keys(suffixes) |> Enum.map(&(title_case(&1)))
    capitalized_values = Map.values(suffixes) |> Enum.map(&(title_case(&1)))
    suffix_values = capitalized_keys ++ capitalized_values
    cond do
      Enum.member?(suffix_values, cleaned_value) -> 
        case Map.has_key?(suffixes, String.upcase(value)) do
          true -> Map.get(suffixes, String.upcase(value))
          false -> cleaned_value
        end
      true -> nil
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

  # Does a standard safe_replace, unless the value to be modified is a nil in
  # which case it just returns a nil.
  defp safe_replace(nil, _, _), do: nil
  defp safe_replace(value, k, v), do: String.replace(value, k, v)

  # Standardizes the spacing around the commas, periods, and newlines and then
  # deletes the periods per the best practices outlined by the USPS.  It also
  # replaces newline characters with commas, and replaces '# <value>' with
  # '#<value>' and then returns the string.
  defp standardize_address(address) when not is_binary(address), do: nil
  defp standardize_address(address) do
    address
      |> safe_replace(~r/\(.+\)/, "")
      |> safe_replace(~r/(?i)\sAND\s/, "&")
      |> safe_replace(~r/(?i)\sI.E.\s/, "")
      |> safe_replace(~r/(?i)\sET\sAL\s/, "")
      |> safe_replace(~r/(?i)\sIN\sCARE\sOF\s/, "")
      |> safe_replace(~r/(?i)\sCARE\sOF\s/, "")
      |> safe_replace(~r/(?i)\sTHE\s/, "")
      |> safe_replace(~r/(?i)\sBY\s/, "")
      |> safe_replace(~r/(?i)\sFOR\s/, "")
      |> safe_replace(~r/(?i)\sAT\s/, "")
      |> safe_replace(~r/(?i)\sALSO\s/, "")
      |> safe_replace(~r/(?i)\sATTENTION\s/, "")
      |> safe_replace(~r/(?i)\sATTN\s/, "")
      |> safe_replace(~r/(?i)\ss#\ss(\S)/, " #\\1")
      |> safe_replace(~r/(?i)P O BOX/, "PO BOX")
      |> safe_replace(~r/(?i)US (\d+)/, "US Hwy \\1")
      |> safe_replace(~r/\n/, ", ")
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

  # Capitalizes the first letter of every word in a string and returns the 
  # title cased string.
  defp title_case(value) when not is_binary(value), do: nil
  defp title_case(value) do
    String.split(value, " ") 
      |> Enum.map(&(String.capitalize(&1))) 
      |> Enum.join(" ")
  end

  # Determines if address list contains a PO Box.
  defp contains_po_box?(address) when not is_list(address), do: false
  defp contains_po_box?([]), do: false
  defp contains_po_box?(address) do
    [head|_] = address
    full_address = address |> Enum.join(" ") |> String.upcase
    !is_keyword?(head) && String.match?(full_address, ~r/BOX/)
  end

  # Determines if a value is a number, fraction, or postal keyword.
  defp is_keyword?(value) when not is_binary(value), do: false
  defp is_keyword?(value) do 
    word = title_case(value)
    units = Application.get_env(:parsing, :secondary_units)
    suffixes = Application.get_env(:parsing, :street_suffixes)
    keywords1 = Map.keys(units) ++ Map.values(units) ++ Map.values(suffixes)
    keywords2 = Map.keys(suffixes)
    cond do
      string_is_number_or_fraction?(word) -> true
      Enum.member?(keywords1, word) -> true
      Enum.member?(keywords2, String.upcase(word)) -> true
      true -> false
    end
  end

  # Detects if a string is a state or not.
  defp is_state?(value) when not is_binary(value), do: false
  defp is_state?(value) do
    state = title_case(value)
    states = Application.get_env(:parsing, :states)
    cond do
      Map.has_key?(states, state) -> true
      Map.values(states) |> Enum.member?(String.upcase(state)) -> true
      true -> false
    end
  end

  # Determines if a value is a possible Suite value.
  defp is_possible_suite_number?(value) when is_number(value), do: true
  defp is_possible_suite_number?(value) do
    values = String.codepoints("abcdefghijklmnopqrstuvqxyz12334567890")
    String.downcase(value) in values
  end

  # Determines if string can be cleanly converted into a number.
  defp string_is_number?(value) when is_number(value), do: true
  defp string_is_number?(value) when not is_binary(value), do: false
  defp string_is_number?(value) do
    is_integer = case Integer.parse(value) do
      :error -> false
      {_, ""} -> true
      {_, _} -> false
    end
    is_float = case Float.parse(value) do
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
          2 -> Enum.all?(values, &(string_is_number?(&1)))
          _ -> false
        end
      true -> false
    end
  end
end