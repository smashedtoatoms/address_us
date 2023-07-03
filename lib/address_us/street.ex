defmodule AddressUS.Street do
  @moduledoc """
  Container for the struct that contains the Street information for an address.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          pmb: String.t(),
          pre_direction: String.t(),
          primary_number: String.t(),
          post_direction: String.t(),
          secondary_designator: String.t(),
          secondary_value: String.t(),
          suffix: String.t()
        }

  @doc """
  Struct containing the Street information.
  """
  defstruct name: nil,
            pmb: nil,
            pre_direction: nil,
            primary_number: nil,
            post_direction: nil,
            secondary_designator: nil,
            secondary_value: nil,
            suffix: nil
end
