defmodule JobSvcTest do
  use ExUnit.Case
  doctest JobSvc

  test "greets the world" do
    assert JobSvc.hello() == :world
  end
end
