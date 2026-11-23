#!/usr/bin/env python3
"""Fake MPRIS player for tests: plays a 40 s track, position follows the clock.
usage: mock_player.py [identity] [seconds-until-track-2]"""
import sys, time
from gi.repository import Gio, GLib

IDENT = sys.argv[1] if len(sys.argv) > 1 else "Mock Player"
SWITCH = float(sys.argv[2]) if len(sys.argv) > 2 else 0
XML = """<node>
<interface name="org.mpris.MediaPlayer2">
 <property name="Identity" type="s" access="read"/><property name="DesktopEntry" type="s" access="read"/>
 <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
 <property name="HasTrackList" type="b" access="read"/>
 <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
 <method name="PlayPause"/><method name="Play"/><method name="Pause"/><method name="Next"/><method name="Previous"/><method name="Stop"/>
 <method name="Seek"><arg type="x" direction="in"/></method>
 <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
 <signal name="Seeked"><arg type="x"/></signal>
 <property name="PlaybackStatus" type="s" access="read"/><property name="Metadata" type="a{sv}" access="read"/>
 <property name="Position" type="x" access="read"/><property name="Rate" type="d" access="readwrite"/>
 <property name="Volume" type="d" access="readwrite"/><property name="LoopStatus" type="s" access="readwrite"/>
 <property name="Shuffle" type="b" access="readwrite"/>
 <property name="MinimumRate" type="d" access="read"/><property name="MaximumRate" type="d" access="read"/>
 <property name="CanGoNext" type="b" access="read"/><property name="CanGoPrevious" type="b" access="read"/>
 <property name="CanPlay" type="b" access="read"/><property name="CanPause" type="b" access="read"/>
 <property name="CanSeek" type="b" access="read"/><property name="CanControl" type="b" access="read"/>
</interface></node>"""
TRACKS = [("Test Artist", "First Song", "Test Album", 40), ("Other Artist", "Second Song", "", 40)]
st = {"i": 0, "start": time.monotonic()}
def meta():
    a, t, al, ln = TRACKS[st["i"]]
    d = {"mpris:trackid": GLib.Variant("o", f"/mock/{st['i']}"), "xesam:title": GLib.Variant("s", t),
         "xesam:artist": GLib.Variant("as", [a]), "mpris:length": GLib.Variant("x", ln * 1000000)}
    if al: d["xesam:album"] = GLib.Variant("s", al)
    return d
def pos(): return int((time.monotonic() - st["start"]) * 1e6)
def getp(conn, sender, path, iface, prop):
    v = {"Identity": GLib.Variant("s", IDENT), "DesktopEntry": GLib.Variant("s", "mocktest"),
         "CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", False),
         "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
         "PlaybackStatus": GLib.Variant("s", "Playing"), "Metadata": GLib.Variant("a{sv}", meta()),
         "Position": GLib.Variant("x", pos()), "Rate": GLib.Variant("d", 1.0), "Volume": GLib.Variant("d", 1.0),
         "LoopStatus": GLib.Variant("s", "None"), "Shuffle": GLib.Variant("b", False),
         "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0)}.get(prop)
    return v if v is not None else GLib.Variant("b", True)
def call(conn, sender, path, iface, method, params, inv): inv.return_value(None)
def on_bus(conn, name):
    for i in Gio.DBusNodeInfo.new_for_xml(XML).interfaces:
        conn.register_object("/org/mpris/MediaPlayer2", i, call, getp, None)
    if SWITCH:
        def switch():
            st["i"] = 1; st["start"] = time.monotonic()
            conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", {"Metadata": GLib.Variant("a{sv}", meta())}, [])))
            return False
        GLib.timeout_add(int(SWITCH * 1000), switch)
Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.mocktest", 0, on_bus, None, None)
GLib.MainLoop().run()
