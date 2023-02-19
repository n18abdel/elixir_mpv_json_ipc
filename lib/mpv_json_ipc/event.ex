defmodule MpvJsonIpc.Event do
  @moduledoc false
  use GenServer

  @impl true
  def init(opts) do
    {:ok,
     {%{event_callbacks: %{}, replies: %{}, property_callbacks: %{}, keybindings: %{}},
      opts[:seed]}}
  end

  @impl true
  def handle_call({:reply, request_id, from}, _, {state, seed}) do
    timer_ref = Process.send_after(self(), {:reply_timeout, request_id, from}, timeout())

    new_state =
      state
      |> put_in([:replies, request_id], {from, timer_ref})

    {:reply, :ok, {new_state, seed}}
  end

  for item <- ["event_callback", "keybinding", "property_callback"] do
    func = :"add_#{item}"
    key1 = :"#{item}s"
    @impl true
    def handle_call({unquote(func), key2, callback}, _, {state, seed}) do
      new_state =
        state
        |> put_in([unquote(key1), key2], callback)

      {:reply, :ok, {new_state, seed}}
    end
  end

  @impl true
  def handle_call({:remove_property_callback, observer_id}, _, {state, seed}) do
    {_, new_state} =
      state
      |> pop_in([:property_callbacks, observer_id])

    {:reply, :ok, {new_state, seed}}
  end

  @impl true
  def handle_cast(%{error: _error, request_id: request_id} = e, {state, seed}) do
    {{{reply_ref, reply_pid}, timer_ref}, new_state} =
      state
      |> pop_in([:replies, request_id])

    Process.cancel_timer(timer_ref)
    send(reply_pid, {reply_ref, format(e)})

    {:noreply, {new_state, seed}}
  end

  @impl true
  def handle_cast(%{event: _event} = e, {state, seed}) do
    callbacks(e, state)
    |> Stream.filter(&is_function/1)
    |> Enum.each(fn callback ->
      Task.Supervisor.start_child(MpvJsonIpc.Task.name(seed), fn -> do_callback(e, callback) end)
    end)

    {:noreply, {state, seed}}
  end

  @impl true
  def handle_info({:reply_timeout, request_id, {reply_ref, reply_pid}}, {state, seed}) do
    {_, new_state} =
      state
      |> pop_in([:replies, request_id])

    send(reply_pid, {reply_ref, {:error, :timeout}})

    {:noreply, {new_state, seed}}
  end

  @doc false
  def name(seed), do: {:via, Registry, {Registry.MpvJsonIpc, "#{__MODULE__}#{seed}"}}

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: name(opts[:seed]))

  def reply(server, request_id, from), do: GenServer.call(server, {:reply, request_id, from})

  for func <- [:add_event_callback, :add_keybinding, :add_property_callback] do
    def unquote(func)(server, key, callback),
      do: GenServer.call(server, {unquote(func), key, callback})
  end

  def remove_property_callback(server, observer_id),
    do: GenServer.call(server, {:remove_property_callback, observer_id})

  def receive(server, data), do: GenServer.cast(server, data)

  defp timeout, do: __MODULE__ |> Application.get_application() |> Application.get_env(:timeout)

  defp format(%{error: "success", data: data}), do: {:ok, data}
  defp format(%{error: "success"}), do: :ok
  defp format(%{error: error}), do: {:error, error}

  defp do_callback(%{event: "log-message"} = e, callback), do: callback.(e)
  defp do_callback(event, callback), do: callback.(event[:data])

  defp callbacks(%{event: "client-message", args: ["custom-bind", name]} = e, state),
    do: [Map.get(state[:keybindings], name), Map.get(state[:event_callbacks], e.event)]

  defp callbacks(%{event: "property-change"} = e, state),
    do: [Map.get(state[:property_callbacks], e[:id]), Map.get(state[:event_callbacks], e.event)]

  defp callbacks(event, state),
    do: [Map.get(state[:event_callbacks], event.event)]
end
