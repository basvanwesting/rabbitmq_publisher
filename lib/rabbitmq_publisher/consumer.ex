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
    Logger.error("Channel went down")
    {:stop, {:connection_lost, reason}, nil}
  end

  def handle_events([event], _from, chan) do
    IO.puts("received #{event}")
    AMQP.Basic.publish(chan, @exchange, "", event)
    IO.puts("finished #{event}")

    {:noreply, [], chan}
  end

  defp setup_queue(chan) do
    with {:ok, _} <- Queue.declare(chan, @queue_error, durable: true),
         # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
         {:ok, _} <- Queue.declare(chan, @queue,
           durable: true,
           arguments: [
             {"x-dead-letter-exchange", :longstr, ""},
             {"x-dead-letter-routing-key", :longstr, @queue_error}
           ]
         ),
         :ok <- Exchange.fanout(chan, @exchange, durable: true),
         :ok <- Queue.bind(chan, @queue, @exchange) do
      :ok
    else
      error ->
        Logger.error("Failed to setup queue #{@queue}: #{inspect error}. Propgating error")
        error
    end
  # Queue.declare can also exit, so we need to handle that, otherwise we run into reached_max_restart_intensity
  catch
    :exit, reason -> {:exit, reason}
  end
end
