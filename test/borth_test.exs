defmodule BorthTest do
  use ExUnit.Case
  import Borth, only: [sigil_B: 2]
  doctest Borth

  test "hello world" do
    ~B"""
    : main 1 2 3 ;
    """
    |> IO.inspect()
  end
end
