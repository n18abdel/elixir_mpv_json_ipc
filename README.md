# MpvJsonIpc

Elixir API to [MPV](https://mpv.io/manual/master) using JSON IPC.
Inspired by this Python [library](https://github.com/iwalton3/python-mpv-jsonipc).

## Installation

The package can be installed
by adding `mpv_json_ipc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mpv_json_ipc, "~> 0.1.0"}
  ]
end
```

The docs can
be found at <https://hexdocs.pm/mpv_json_ipc>.

## Basic usage

```elixir
require MpvJsonIpc.Mpv
{:ok, sup} = MpvJsonIpc.Mpv.Sup.start_link()
main = MpvJsonIpc.Mpv.Sup.main(sup)

MpvJsonIpc.Mpv.on_event main, "seek" do
 IO.inspect("seeking")
end

MpvJsonIpc.Mpv.property_observer main, "pause" do
 if pause, do: IO.inspect("in pause"), else: IO.inspect("playing")
end

MpvJsonIpc.Mpv.on_keypress main, "g" do
 IO.inspect("key g pressed")
end

:ok = MpvJsonIpc.ensure_loaded()

MpvJsonIpc.Mpv.Commands.loadfile(main, "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
MpvJsonIpc.Mpv.Properties.Volume.set(main, 30)
```
