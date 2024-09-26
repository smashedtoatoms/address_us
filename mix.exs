defmodule AddressUS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :address_us,
      version: "0.4.3",
      elixir: ">= 1.6.0",
      name: "AddressUS",
      source_url: "https://github.com/smashedtoatoms/address_us",
      homepage_url: "https://github.com/smashedtoatoms/address_us",
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    Library for parsing US Addresses into their individual parts.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jason Legler"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/smashedtoatoms/address_us",
      }
    ]
  end
end
