defmodule MpvJsonIpc do
  @moduledoc """
  Utilities.
  """
  @doc false
  use GenServer, restart: :transient

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call(:loaded, _, to_reply) do
    :persistent_term.put(__MODULE__, true)
    to_reply |> Enum.map(&GenServer.reply(&1, :ok))
    {:stop, :normal, :ok, to_reply}
  end

  @impl true
  def handle_call(:ensure_loaded, from, to_reply) do
    to_reply = [from | to_reply]
    {:noreply, to_reply}
  end

  @doc false
  def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

  def __loaded__, do: GenServer.call(__MODULE__, :loaded)

  @doc """
  Checks whether the library is fully loaded.

  See [Properties and commands](properties-and-commands.md).
  """
  def loaded?, do: :persistent_term.get(__MODULE__, false)

  @doc """
  Blocks until the library is fully loaded.

  See [Properties and commands](properties-and-commands.md).
  """
  def ensure_loaded() do
    if not loaded?() do
      GenServer.call(__MODULE__, :ensure_loaded, :infinity)
    else
      :ok
    end
  end

  @doc """
  Returns a list of running supervisors.

  ## Examples
      iex> MpvJsonIpc.Mpv.Sup.start_link()
      {:ok, #PID<0.2884.0>}
      iex> MpvJsonIpc.running_sups()
      [{"Elixir.MpvJsonIpc.Mpv.Sup114384777898228", #PID<0.2884.0>}]
  """
  def running_sups do
    Registry.MpvJsonIpc
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {key, _} -> key |> String.contains?("Sup") end)
  end
end
