for i <- 1..10 , do: RabbitmqPublisher.Producer.enqueue("hello #{i}")
for i <- 11..20 , do: RabbitmqPublisher.Producer.enqueue("hello #{i}")
