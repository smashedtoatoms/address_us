defmodule AddressUS.Mixfile do
  use Mix.Project

  def project do
    [app: :address_us,
     version: "0.4.0",
     elixir: ">= 1.6.0",
     name: "AddressUS",
     source_url: "https://github.com/smashedtoatoms/address_us",
     homepage_url: "https://github.com/smashedtoatoms/address_us",
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be hex.pm packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:earmark, "~> 1.2.5", only: :dev},
      {:ex_doc, "~> 0.18.4", only: :dev}
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
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/smashedtoatoms/address_us",
        "Docs" => "https://smashedtoatoms.github.io/address_us"
      }
    ]
  end
end
