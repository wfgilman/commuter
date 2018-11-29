defmodule BartTest do
  use ExUnit.Case
  doctest Bart

  test "greets the world" do
    assert Bart.hello() == :world
  end
end
