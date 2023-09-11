defmodule AddressUS.Util do
  # Does a standard safe_upcase, unless the value to be upcased is a nil, in
  # which case it returns ""
  def safe_upcase(nil), do: ""
  def safe_upcase(value), do: String.upcase(value)

  # Does a standard safe_has_key, unless the value to be checked is a nil, in
  # which case it returns false.
  def safe_has_key?(_, nil), do: false
  def safe_has_key?(map, key), do: Map.has_key?(map, key)

  # Does a standard String.contains?, unless the value for which to search is
  # an empty string, in which case it returns false.
  def safe_contains?(_, ""), do: false
  def safe_contains?(value, k), do: String.contains?(value, k)

  # Does a standard safe_replace, unless the value to be modified is a nil in
  # which case it just returns a nil.
  def safe_replace(nil, _, _), do: nil
  def safe_replace(value, k, v), do: String.replace(value, k, v)

  # Does a standard safe_starts_with?, unless the value to be modified is a nil
  # in which case it returns false.
  def safe_starts_with?(nil, _), do: false
  def safe_starts_with?(value, k), do: String.starts_with?(value, k)

  # Capitalizes the first letter of every word in a string and returns the
  # title cased string.
  def title_case(value) when not is_binary(value), do: nil

  def title_case(value) do
    word_endings = ["ST", "ND", "RD", "TH"]

    make_title_case = fn word ->
      letters = safe_replace(word, ~r/\d+/, "")

      cond do
        String.downcase(word) == "us" ->
          "US"

        Regex.match?(~r/^(\d)/, word) && Enum.member?(word_endings, letters) ->
          safe_upcase(word)

        true ->
          String.split(word, "-")
          |> Enum.map(&String.capitalize(&1))
          |> Enum.join("-")
      end
    end

    String.split(value, " ")
    |> Enum.map(&make_title_case.(&1))
    |> Enum.join(" ")
  end
end
