defmodule EmailSvcTest do
  use ExUnit.Case
  doctest EmailSvc

  test "greets the world" do
    assert EmailSvc.hello() == :world
  end
end
