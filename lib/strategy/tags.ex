defmodule ClusterDO.Strategy.Tags do
  use GenServer
  use Cluster.Strategy
  import Cluster.Logger
  alias Cluster.Strategy.State

  @default_polling_interval 5_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]) do
    init([%State{state | :meta => MapSet.new()}])
  end

  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, %State{} = state) do
    {:noreply, load(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def load(%State{topology: topology, meta: meta} = state) do
    new_nodelist = MapSet.new(get_nodes(state))
    nodes = Node.list()

    added =
    MapSet.union(
    MapSet.difference(new_nodelist, meta),
    MapSet.new(Enum.filter(new_nodelist, &(&1 not in nodes)))
    )

    removed = MapSet.difference(state.meta, new_nodelist)

    new_nodelist =
    case Cluster.Strategy.disconnect_nodes(
    topology,
    state.disconnect,
    state.list_nodes,
    MapSet.to_list(removed)
    ) do
      :ok ->
        new_nodelist

      {:error, bad_nodes} ->
        # Add back the nodes which should have been removed, but which couldn't be for some reason
      Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
        MapSet.put(acc, n)
      end)
    end

    new_nodelist =
    case Cluster.Strategy.connect_nodes(
    topology,
    state.connect,
    state.list_nodes,
    MapSet.to_list(added)
    ) do
      :ok ->
        new_nodelist

      {:error, bad_nodes} ->
        # Remove the nodes which should have been added, but couldn't be for some reason
      Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
        MapSet.delete(acc, n)
      end)
    end

    Process.send_after(self(), :load, polling_interval(state))

    %State{state | :meta => new_nodelist}
  end


  defp polling_interval(%State{config: config}) do
    Keyword.get(config, :polling_interval, @default_polling_interval)
  end

  def get_nodes(state) do
    []
  end

end