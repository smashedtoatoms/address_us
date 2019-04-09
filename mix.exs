defmodule AddressUs.MixProject do
  use Mix.Project

  def project do
    [
      app: :address_us,
      version: "0.4.0",
      elixir: ">= 1.6.0",
      name: "AddressUS",
      source_url: "https://github.com/smashedtoatoms/address_us",
      homepage_url: "https://github.com/smashedtoatoms/address_us",
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
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
