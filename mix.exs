defmodule Restez.MixProject do
  use Mix.Project

  def project do
    [
      app: :restez,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "RESTez",
      source_url: "https://github.com/mjlorenzo/restez"
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
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
    ]
  end

  def package() do
    [
      name: "RESTez",
      maintainers: ["Mike Lorenzo"],
      licenses: ["MIT"],
      description: "Library for describing RESTful APIs and autogenerating clients. NOTE: This library is very much still under development, DO NOT USE IN PRODUCTION!",
      links: %{"Source" => "https://github.com/mjlorenzo/restez"}
    ]
  end
end
