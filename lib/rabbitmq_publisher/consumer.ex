defmodule RabbitmqPublisher.Consumer do
  use GenStage
  require Logger
  use AMQP

  #@host "amqp://client:client@bas-rpi4-161.local"
  @exchange    "broadway_tutorial_exchange"
  @queue       "broadway_tutorial"
  @queue_error "#{@queue}_error"
  @reconnect_interval 10_000

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    #{:consumer, nil, subscribe_to: [{RabbitmqPublisher.Producer, max_demand: 1}]}
    send(self(), :connect)
    {:consumer, nil}
  end

  def handle_info(:connect, _chan) do
    with {:ok, conn} <- RabbitmqPublisher.AMQP.get_connection(),
         {:ok, chan} <- Channel.open(conn),
         :ok <- setup_queue(chan),
         :ok <- GenStage.async_subscribe(__MODULE__, to: RabbitmqPublisher.Producer, max_demand: 1) do

      Process.monitor(chan.pid)
      {:noreply, [], chan}
    else
      error ->
        Logger.error("Failed to connect #{@queue}: #{inspect error}. Reconnecting later...")
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, [], nil}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
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
