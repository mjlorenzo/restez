defmodule RestezTest do
  use ExUnit.Case
  doctest Restez

  test "greets the world" do
    assert Restez.hello() == :world
  end
end
