defmodule RabbitmqPublisher.Consumer do
  use GenStage
  use AMQP

  #@host "amqp://client:client@bas-rpi4-161.local"
  @exchange    "broadway_tutorial_exchange"
  @queue       "broadway_tutorial"
  @queue_error "#{@queue}_error"

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    with {:ok, conn} <- RabbitmqPublisher.AMQP.get_connection(),
         {:ok, chan} <- Channel.open(conn),
         :ok <- setup_queue(chan) do
      {:consumer, chan, subscribe_to: [{RabbitmqPublisher.Producer, max_demand: 1}]}
    end
  end

  def handle_events([event], _from, chan) do
    IO.puts("received #{event}")
    AMQP.Basic.publish(chan, @exchange, "", event)
    IO.puts("finished #{event}")

    {:noreply, [], chan}
  end

  defp setup_queue(chan) do
    {:ok, _} = Queue.declare(chan, @queue_error, durable: true)
    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} = Queue.declare(chan, @queue,
                             durable: true,
                             arguments: [
                               {"x-dead-letter-exchange", :longstr, ""},
                               {"x-dead-letter-routing-key", :longstr, @queue_error}
                             ]
                            )
    :ok = Exchange.fanout(chan, @exchange, durable: true)
    :ok = Queue.bind(chan, @queue, @exchange)
  end
end


#{:ok, connection} = AMQP.Connection.open(host: "bas-rpi4-161.local", username: "client", password: "client")
#{:ok, channel} = AMQP.Channel.open(connection)
#AMQP.Queue.declare(channel, "broadway_tutorial")
#AMQP.Basic.publish(channel, "", "broadway_tutorial", "Hello World!")
#IO.puts " [x] Sent 'Hello World!'"
#AMQP.Connection.close(connection)
