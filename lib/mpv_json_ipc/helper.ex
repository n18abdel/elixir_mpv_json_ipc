defmodule MpvJsonIpc.Helper do
  @moduledoc false
  defmacro __using__(_opts) do
    quote location: :keep do
      @doc false
      use GenServer
      require Logger

      defmodule Sup do
        @main_module __MODULE__
                     |> Module.split()
                     |> Enum.take_while(&(&1 != "Sup"))
                     |> Module.concat()

        @moduledoc @main_module == MpvJsonIpc.Mpv &&
                     """
                     A Supervisor for an MPV instance.
                     """

        use Supervisor, restart: :transient

        @impl true
        def init(opts) do
          opts =
            opts
            |> Enum.into(%{
              ipc_server: "/tmp/mpv#{opts[:seed]}",
              start_mpv: true,
              log_level: nil,
              log_handler: nil,
              path: "mpv"
            })

          children = [
            {MpvJsonIpc.Task, opts},
            {MpvJsonIpc.Event, opts},
            {@main_module, opts}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end

        @doc false
        def name(seed), do: {:via, Registry, {Registry.MpvJsonIpc, "#{__MODULE__}#{seed}"}}

        @doc """
        Returns the the server instance that you can interract with using `Mpv`

        ## Examples
            {:ok, sup} = MpvJsonIpc.Mpv.Sup.start_link()
            main = MpvJsonIpc.Mpv.Sup.main(sup)
            # When you don't know the supervisor pid (e.g. MpvJsonIpc.Mpv.Sup directly started in the supervision tree)
            {_, sup} = MpvJsonIpc.running_sups() |> List.first()
            main = MpvJsonIpc.Mpv.Sup.main(sup)
            MpvJsonIpc.Mpv.command(main, "get_property", "playback-time")
        """
        def main(pid),
          do: pid |> Supervisor.which_children() |> List.keyfind!(MpvJsonIpc.Mpv, 0) |> elem(1)

        @doc """
        Starts the the supervisor.

        The following options can be set:

        * `:start_mpv` - Whether to start an MPV instance; default: `true`.
        If this is set to `false`, `:ipc_server` must also be set.
        * `:ipc_server` - the path of the IPC server, of the already running MPV instance.
        * `:path` - the path of the MPV executable.
        If this is not set, it looks for MPV in the `$PATH`.
        * `:log_level` - Whether to receive log messages from the MPV instance.
        If this is set, `:log_handler` must also be set.
        Available levels are described [here](https://mpv.io/manual/master/#options-msg-level)
        * `:log_handler` - a function that process log messages.

        ## Examples
            # Uses the MPV executable found in the `$PATH`
            MpvJsonIpc.Mpv.Sup.start_link()
            # Uses a running MPV connected to /tmp/mpvsocket
            MpvJsonIpc.Mpv.Sup.start_link(start_mpv: false, ipc_server: "/tmp/mpvsocket")
            # Uses the MPV executable found at /path/to/mpv
            MpvJsonIpc.Mpv.Sup.start_link(path: "/path/to/mpv")
            # Calls `IO.inspect/1` on all messages with level `:debug` or above
            MpvJsonIpc.Mpv.Sup.start_link(log_level: :debug, log_handler: &IO.inspect/1)
        """
        def start_link(opts \\ []) do
          seed = Enum.random(0..(2 ** 48))
          opts = opts |> Enum.into(%{seed: seed})

          Supervisor.start_link(__MODULE__, opts, name: name(seed))
        end

        @doc """
        Stops the supervisor.
        """
        def stop(server, reason \\ :normal)

        def stop(server, reason) when is_tuple(server) or is_pid(server),
          do: Supervisor.stop(server, reason)

        def stop(seed, reason), do: __MODULE__.name(seed) |> stop(reason)
      end

      @impl true
      def handle_call({:command, cmd}, _from, {state, seed}) do
        {reply, new_state} = do_command(cmd, state, seed)
        {:reply, reply, {new_state, seed}}
      end

      @doc false
      def name(seed), do: {:via, Registry, {Registry.MpvJsonIpc, "#{__MODULE__}#{seed}"}}
      @doc false
      def start_link(opts \\ []),
        do: GenServer.start_link(__MODULE__, opts, name: name(opts[:seed]))

      @doc """
      Sends the command to the MPV instance.

      Available commands are [here](https://mpv.io/manual/master/#list-of-input-commands).

      ## Examples
          MpvJsonIpc.Mpv.command(server, "get_property", "playback-time")
          MpvJsonIpc.Mpv.command(server, :get_property, :"playback-time")
          MpvJsonIpc.Mpv.command(main, "expand-properties", ["print-text", "${playback-time}"])
          MpvJsonIpc.Mpv.command(server, :set_property, [:pause, true])
          MpvJsonIpc.Mpv.command(server, %{
            name: "loadfile",
            url:
              "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            options: %{
              cache: "yes",
              "demuxer-max-bytes": "100MiB",
              "demuxer-max-back-bytes": "100MiB"
            }
          })
      """
      def command(server, cmd, args \\ [])

      def command(server, cmd, _args) when is_map(cmd),
        do:
          GenServer.call(
            server,
            {:command, %{command: cmd}},
            timeout()
          )

      def command(server, name, args) when (is_binary(name) or is_atom(name)) and is_list(args),
        do:
          GenServer.call(
            server,
            {:command,
             %{
               command: [name] ++ args
             }},
            timeout()
          )

      def command(server, name, arg)
          when (is_binary(name) or is_atom(name)) and (is_binary(arg) or is_atom(arg)),
          do: command(server, name, [arg])

      defp timeout,
        do:
          :timer.seconds(5) +
            (__MODULE__ |> Application.get_application() |> Application.get_env(:timeout))

      defp wrapper_path,
        do:
          System.tmp_dir!()
          |> Path.join(__MODULE__ |> Application.get_application() |> to_string)
          |> Path.join("wrapper.sh")

      defp do_init(opts) do
        Logger.debug("Mpv basic init", seed: opts[:seed])

        opts =
          opts
          |> Enum.into(%{
            ipc_server: "/tmp/mpvsocket",
            start_mpv: true,
            log_level: nil,
            log_handler: nil,
            path: "mpv"
          })

        if opts[:start_mpv] do
          Port.open(
            {:spawn_executable, wrapper_path()},
            [
              :binary,
              :exit_status,
              args: [
                opts[:path],
                "--idle",
                "--input-ipc-server=#{opts[:ipc_server]}",
                "--no-input-terminal",
                "--no-terminal"
              ]
            ]
          )
        end

        request_id = observer_id = keybind_id = 1
        {:ok, _} = MpvJsonIpc.Socket.start_link(opts)
        {%{request_id: request_id, observer_id: observer_id, keybind_id: keybind_id}, opts}
      end

      defp log_setup({log_level, log_handler}, {state, seed}) do
        Logger.debug("Mpv logs setup", seed: seed)

        new_state =
          if log_level && log_handler && is_function(log_handler, 1) do
            :ok =
              MpvJsonIpc.Event.name(seed)
              |> MpvJsonIpc.Event.add_event_callback("log-message", log_handler)

            cmd = %{command: [:request_log_messages, log_level]}
            {:ok, new_state} = do_command(cmd, state, seed)
            new_state
          else
            state
          end
      end

      defp add_request_id({cmd, state}, seed, from) when is_map(cmd) do
        :ok = MpvJsonIpc.Event.name(seed) |> MpvJsonIpc.Event.reply(state[:request_id], from)
        cmd = cmd |> Map.put(:request_id, state[:request_id])
        new_state = state |> Map.update!(:request_id, &(&1 + 1))
        {cmd, new_state}
      end

      defp add_request_id({cmd, _state} = arg, _seed, _from)
           when is_binary(cmd),
           do: arg

      defp do_command(cmd, state, seed) do
        ref = make_ref()

        {cmd, new_state} = add_request_id({cmd, state}, seed, {ref, self()})

        :ok = MpvJsonIpc.Socket.name(seed) |> MpvJsonIpc.Socket.send(cmd)

        reply =
          receive do
            {^ref, reply} ->
              reply
          after
            timeout() ->
              {:error, :timeout}
          end

        {reply, new_state}
      end
    end
  end
end
