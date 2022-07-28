defmodule BorthTest do
  use ExUnit.Case
  doctest Borth

  test "greets the world" do
    assert Borth.hello() == :world
  end
end
