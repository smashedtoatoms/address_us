defmodule AddressUS.Phone do
  import AddressUS.Util

  @doc """
  Removes non-numeric characters from the phone number and then returns the
  integer.
  ## Examples
      iex> AddressUS.clean_phone_number("(303) 310-7802")
      3033107802
  """
  def clean_phone_number(nil), do: nil

  def clean_phone_number(phone) do
    {phone_integer, _} =
      phone
      |> safe_replace(~r/\s+/, "")
      |> safe_replace("+1", "")
      |> safe_replace("-", "")
      |> safe_replace("(", "")
      |> safe_replace(")", "")
      |> Integer.parse()

    phone_integer
  end

  @doc """
  Removes country code and associated punctuation from the phone number.
  ## Examples
      iex> AddressUS.filter_country_code("+1 303-310-7802")
      "303-310-7802"
      iex> AddressUS.filter_country_code("+1 (303) 310-7802")
      "(303) 310-7802"
      iex> AddressUS.filter_country_code("+1-303-310-7802")
      "303-310-7802"
      iex> AddressUS.filter_country_code("1-303-310-7802")
      "303-310-7802"
  """
  def filter_country_code(nil), do: nil

  def filter_country_code(phone) do
    phone
    |> safe_replace(~r/^1\s+|^1-|^\+1\s+|^\+1-/, "")
    |> safe_replace(~r/^1\(|^1\s+\(/, "(")
    |> safe_replace(~r/\)(\d)/, ") \\1")
  end
end
