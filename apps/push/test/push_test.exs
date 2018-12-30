defmodule PushTest do
  use ExUnit.Case
  doctest Push

  test "greets the world" do
    assert Push.hello() == :world
  end
end
