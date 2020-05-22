%include "icecast_credentials.liq"

set("frame.audio.samplerate", 44100)

set("harbor.bind_addrs", ["0.0.0.0"])
set("harbor.max_connections", 3)
set("harbor.reverse_dns", false)
set("harbor.verbose", true)

set("server.telnet", true)
set("server.telnet.bind_addr", "127.0.0.1")
set("server.telnet.port", 8085)
set("server.telnet.revdns", false)
set("server.timeout", 120.)

fallback_audio = blank()

divog_a = mksafe(
  id="divog_a_http_safe",
  audio_to_stereo(
    drop_midi(
      drop_video(
        input.http(
          id="divog_a_http",
          "http://stream.c-radar.de:8000/divog-a.mp3"
        )
      )
    )
  )
)

divog_b = mksafe(
  id="divog_b_http_safe",
  audio_to_stereo(
    drop_midi(
      drop_video(
        input.http(
          id="divog_b_http",
          "http://stream.c-radar.de:8000/divog-b.mp3"
        )
      )
    )
  )
)

divog_a_blank = ref true
divog_b_blank = ref true

divog_a_on_blank = on_blank(
  id="divog_a_blank_detection",
  max_blank=60.,
  min_noise=0.5,
  start_blank=true,
  track_sensitive=false,
  on_noise = {
    log("a noisy")
    divog_a_blank := false;
  },
  {
    log("a silent")
    divog_a_blank := true;
  },
  divog_a
)

divog_b_on_blank = on_blank(
  id="divog_b_blank_detection",
  max_blank=60.,
  min_noise=0.5,
  start_blank=true,
  track_sensitive=false,
  on_noise = {
    log("b noisy")
    divog_b_blank := false;
  },
  {
    log("b silent")
    divog_b_blank := true;
  },
  divog_b
)

# activate blank detection
divog_a_blank_dummy = output.dummy(divog_a_on_blank)
divog_b_blank_dummy = output.dummy(divog_b_on_blank)

source_name = interactive.string("active_source", "a")

switched = switch(
  track_sensitive=false,
  [
    (
      {
        (not !divog_a_blank) and (source_name() == "a")
      },
      divog_a_on_blank
    ),
    (
      {
        (not !divog_b_blank) and (source_name() == "b")
      },
      divog_b_on_blank
    ),
    ({true}, fallback_audio)
  ],
  id="divog_switch"
)

divog_main = output.icecast(
  id="divog_main",
  description="Digital Verteiltes Online Gulasch",
  genre="various",
  host=main_ice_host,
  port=main_ice_port,
  password=main_ice_pass,
  url="https://entropia.de/GPN20",
  name="DiVOG",
  mount="divog.mp3",
  %mp3.cbr(
    stereo=true,
    stereo_mode="stereo",
    internal_quality=6,
    bitrate=128
  ),
  switched
)
