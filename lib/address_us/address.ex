defmodule AddressUS.Address do
  @moduledoc """
  Container for the struct that contains the Address information.
  """

  alias AddressUS.Street

  @type t :: %__MODULE__{
          city: String.t(),
          plus_4: String.t(),
          street: Street.t(),
          state: String.t(),
          postal: String.t()
        }

  @doc """
  Struct containing Address information.
  """
  defstruct city: nil, plus_4: nil, street: nil, state: nil, postal: nil
end
