defmodule EventBus.LocalConsumer do
  @moduledoc """
  The GenEvent handler implementation is a simple consumer.
  It will receive all events from other pars of the system and resent them into Bus
  """

  use GenStage

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok)
  end

  # Callbacks

  def init(:ok) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.
    {:consumer, :ok, subscribe_to: [EventBus.Broadcaster]}
  end

  def handle_events(events, _from, state) do
    for {topic, event} <- events do
      broadcast(topic, event)
      # Hook to broadcast all events to WS
      broadcast(EventBus.global(), event)
    end

    {:noreply, [], state}
  end

  # Send event to all subscribers
  defp broadcast(topic, message) when is_binary(topic) do
    Registry.dispatch(LocalPubSub, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)
  end
end
