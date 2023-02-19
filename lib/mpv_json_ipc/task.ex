defmodule MpvJsonIpc.Task do
  @moduledoc false
  def start_link(opts), do: Task.Supervisor.start_link(name: name(opts[:seed]))
  @doc false
  def name(seed), do: {:via, Registry, {Registry.MpvJsonIpc, "#{__MODULE__}#{seed}"}}

  def child_spec(opts) do
    Task.Supervisor.child_spec(name: name(opts[:seed]))
  end
end
