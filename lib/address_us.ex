defmodule AddressUS do
  alias AddressUS.Config

  import AddressUS.Util

  @doc """
  Abbreviates the state provided.
  ## Example
      iex> AddressUS.abbreviate_state("Wyoming")
      "WY"
      iex> AddressUS.abbreviate_state("wyoming")
      "WY"
      iex> AddressUS.abbreviate_state("Wyomin")
      "Wyomin"
      iex> AddressUS.abbreviate_state(nil)
      nil
  """
  def abbreviate_state(nil), do: nil

  def abbreviate_state(raw_state) do
    state = title_case(raw_state)

    states = Config.states()

    cond do
      safe_has_key?(states, state) == true ->
        Map.get(states, state)

      Enum.member?(Map.values(states), safe_upcase(state)) == true ->
        safe_upcase(state)

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
    codes = Config.countries()
    country = safe_upcase(country_name)

    case Enum.member?(Map.values(codes), country) do
      true -> country
      false -> Map.get(codes, country, country_name)
    end
  end
end
