%include "icecast_credentials.liq"

set("log.file", true)
set("log.stdout", true)
set("log.file.path", "/home/divog/liquidsoap-switch.log")
set("log.unix_timestamp", true)

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

divog_a_input = mksafe(
  id="divog_a_http_safe",
  audio_to_stereo(
    drop_midi(
      drop_video(
        input.http(
          id="divog_a_http",
          "http://localhost/input-a"
        )
      )
    )
  )
)

divog_b_input = mksafe(
  id="divog_b_http_safe",
  audio_to_stereo(
    drop_midi(
      drop_video(
        input.http(
          id="divog_b_http",
          "http://localhost/input-b"
        )
      )
    )
  )
)

moderation_input = mksafe(
  id="moderation_http_safe",
  audio_to_stereo(
    drop_midi(
      drop_video(
        input.http(
          id="moderation_http",
          "http://localhost/mod"
        )
      )
    )
  )
)

divog_a_blank = ref true
divog_b_blank = ref true
moderation_blank = ref true

divog_a = on_blank(
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
  divog_a_input
)

divog_b = on_blank(
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
  divog_b_input
)

moderation_on_blank = on_blank(
  id="moderation_blank_detection",
  max_blank=60.,
  min_noise=0.5,
  start_blank=true,
  track_sensitive=false,
  on_noise = {
    log("moderation noisy")
    moderation_blank := false;
  },
  {
    log("moderation silent")
    moderation_blank := true;
  },
  moderation_input
)

# activate blank detection
divog_a_blank_dummy = output.dummy(divog_a)
divog_b_blank_dummy = output.dummy(divog_b)
moderation_blank_dummy = output.dummy(moderation)

source_name = interactive.string("active_source", "a")

switched = switch(
  track_sensitive=false,
  [
    (
      {
        (not !moderation_blank) and (source_name() == "mod"
      },
      moderation
    ),
    (
      {
        (not !divog_a_blank) and (source_name() == "a")
      },
      divog_a
    ),
    (
      {
        (not !divog_b_blank) and (source_name() == "b")
      },
      divog_b
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
  mount=main_ice_mount,
  %mp3.cbr(
    internal_quality=6,
    bitrate=128
  ),
  switched
)
