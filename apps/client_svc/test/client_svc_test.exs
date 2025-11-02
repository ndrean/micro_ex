defmodule ClientSvcTest do
  use ExUnit.Case
  doctest ClientSvc

  test "greets the world" do
    assert ClientSvc.hello() == :world
  end
end
