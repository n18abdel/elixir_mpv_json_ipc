# Properties and Commands

Upon loading, the library creates the modules `MpvJsonIpc.Mpv.Commands` and `MpvJsonIpc.Mpv.Properties` using the executable found in the `$PATH`.
You can use them once the function `MpvJsonIpc.loaded?/0` returns `true`, or once the function `MpvJsonIpc.ensure_loaded/0` returns.

## Properties

For each property returned by the MPV command `get_property property-list`, the module `MpvJsonIpc.Mpv.Properties.<property>` is created, where `<property>` is uppercased and the dashes are replaced with underscores. It contains the functions `get(server)` and `set(server, value)`.

```elixir
MpvJsonIpc.Mpv.Properties.Volume.set(server, 30)
MpvJsonIpc.Mpv.Properties.Volume.get(server)
MpvJsonIpc.Mpv.Properties.Pause.set(server, true)
MpvJsonIpc.Mpv.Properties.Speed.set(server, 1)
MpvJsonIpc.Mpv.Properties.Time_pos.get(server)
```

## Commands

For each command returned by the MPV command `get_property command-list`, the function `MpvJsonIpc.Mpv.Commands.<command>(args)` is created, where the dashes in `<command>` are replaced with underscores.

```elixir
MpvJsonIpc.Mpv.Commands.loadfile(server, "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
MpvJsonIpc.Mpv.Commands.seek(server, [0, :absolute])
```
