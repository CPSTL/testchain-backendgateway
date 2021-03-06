defmodule Proxy do
  @moduledoc """
  Proxy service functions
  """

  require Logger

  alias Proxy.ExChain
  alias Proxy.Chain.Worker
  alias Proxy.Chain.Supervisor, as: ChainSupervisor

  @doc """
  Start new/existing chain
  """
  @spec start(binary | map(), nil | pid) :: {:ok, binary} | {:error, term()}
  def start(id_or_config, pid \\ nil)

  def start(id, pid) when is_binary(id) do
    case ChainSupervisor.start_chain(id, :existing, pid) do
      :ok ->
        {:ok, id}

      {:ok, _} ->
        {:ok, id}

      err ->
        Logger.error("#{id}: Something wrong: #{inspect(err)}")
        {:error, "failed to start chain"}
    end
  end

  def start(config, pid) when is_map(config) do
    with {:node, node} when not is_nil(node) <- {:node, Proxy.NodeManager.node()},
         {:id, id} when is_binary(id) <- {:id, Proxy.ExChain.unique_id(node)},
         {:ok, _} <-
           config
           |> Map.put(:id, id)
           |> Map.put(:node, node)
           |> Map.put(:clean_on_stop, false)
           |> ChainSupervisor.start_chain(:new, pid) do
      {:ok, id}
    else
      {:node, _} ->
        {:error, "No active ex_testchain node connected !"}

      {:id, _} ->
        {:error, "Failed to generrate new id for EVM"}

      {:error, err} ->
        {:error, err}

      err ->
        Logger.error("Failed to start EVM: #{inspect(err)}")
        {:error, "Unknown error"}
    end
  end

  @doc """
  Terminate chain
  """
  @spec stop(binary) :: :ok
  def stop(id) do
    id
    |> Worker.get_pid()
    |> GenServer.cast(:stop)
  end

  @doc """
  Send take snapshot command to worker
  """
  @spec take_snapshot(Chain.evm_id(), binary()) :: :ok | {:error, term()}
  def take_snapshot(id, description \\ "") do
    id
    |> Worker.get_pid()
    |> GenServer.call({:take_snapshot, description})
  end

  @doc """
  Will send command to the chain to revert snapshot.
  `:ok` will mean that reverting snapshot process started you have to wait for an event
  about complition
  """
  @spec revert_snapshot(Chain.evm_id(), binary) :: :ok | {:error, term()}
  def revert_snapshot(id, snapshot_id) do
    id
    |> Worker.get_pid()
    |> GenServer.call({:revert_snapshot, snapshot_id})
  end

  @doc """
  Load snapshot details
  """
  @spec get_snapshot(binary) :: map() | ExChain.ex_response()
  def get_snapshot(snapshot_id) do
    Proxy.NodeManager.node()
    |> ExChain.get_snapshot(snapshot_id)
  end

  @doc """
  Binding to remove snapshot from ex_testchain
  """
  @spec remove_snapshot(binary) :: :ok | ExChain.ex_response()
  def remove_snapshot(snapshot_id) do
    Proxy.NodeManager.node()
    |> ExChain.remove_snapshot(snapshot_id)
  end

  @doc """
  Alias for uploading snapshot to storage
  File has to be already placed to snapshot store
  """
  @spec upload_snapshot(binary, Chain.evm_type(), binary) :: {:ok, term} | ExChain.ex_response()
  def upload_snapshot(snapshot_id, chain_type, description \\ "") do
    Proxy.NodeManager.node()
    |> ExChain.upload_snapshot(snapshot_id, chain_type, description)
  end

  @doc """
  Remove all details about chain by id
  """
  @spec clean(binary) :: :ok | {:error, binary}
  def clean(id) do
    with {:node, node} when not is_nil(node) <- {:node, Proxy.NodeManager.node()},
         :ok <- ExChain.clean(node, id),
         _ <- Proxy.Chain.Storage.delete(id) do
      :ok
    else
      {:node, _} ->
        {:error, "No active ex_testchain node connected !"}

      err ->
        Logger.error("Failed to clean up chain #{id} details #{inspect(err)}")
        {:error, "failed to clean up chain #{id} details"}
    end
  end

  @doc """
  Load list of snapshots from random ex_testchain node
  """
  @spec snapshot_list(Chain.evm_type()) :: [map()]
  def snapshot_list(chain_type) do
    with {:node, node} when not is_nil(node) <- {:node, Proxy.NodeManager.node()},
         list <- ExChain.snapshot_list(node, chain_type),
         list <- Enum.map(list, &Map.from_struct/1) do
      list
    else
      err ->
        Logger.error("Failed to load list of snapshots for #{chain_type} err: #{inspect(err)}")

        []
    end
  end

  @doc """
  Get details about chain by it's id
  """
  @spec details(binary) :: nil | map()
  def details(id), do: Proxy.Chain.Storage.get(id)

  @doc """
  List of all avaialbe chains
  """
  @spec chain_list() :: [map()]
  def chain_list(), do: Proxy.Chain.Storage.all()

  @doc """
  Get chains version
  """
  @spec version() :: binary | {:error, term()}
  def version() do
    Proxy.NodeManager.node()
    |> ExChain.version()
  end
end
