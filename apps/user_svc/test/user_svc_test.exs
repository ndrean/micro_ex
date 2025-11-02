defmodule UserSvcTest do
  use ExUnit.Case
  doctest UserSvc

  test "greets the world" do
    assert UserSvc.hello() == :world
  end
end
