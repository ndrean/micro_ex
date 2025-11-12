defmodule ImageSvcTest do
  use ExUnit.Case
  doctest ImageSvc

  test "greets the world" do
    assert ImageSvc.hello() == :world
  end
end
