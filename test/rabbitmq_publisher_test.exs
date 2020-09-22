defmodule RabbitmqPublisherTest do
  use ExUnit.Case
  doctest RabbitmqPublisher

  test "greets the world" do
    assert RabbitmqPublisher.hello() == :world
  end
end
