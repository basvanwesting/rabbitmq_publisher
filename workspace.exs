for i <- 1..10 do
  RabbitmqPublisher.Producer.enqueue("hello #{i}")
end
