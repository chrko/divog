%include "icecast_credentials.liq"
%include "common-settings.liq"
%include "funcs.liq"

set("log.file.path", "/home/divog/liquidsoap-switch.log")
set("server.telnet.port", 9000)

fallback_audio = blank()

divog_a_input = in_http("divog_a", "http://localhost/input-a")
divog_b_input = in_http("divog_b", "http://localhost/input-b")
moderation_input = in_http("moderation", "http://localhost/mod")

dump("divog_a_input", divog_a_input)
dump("divog_b_input", divog_b_input)

def blank_detecter(name, blank_ref, source, ~max_blank=60., ~min_noise=0.5)
  src = on_blank(
    id=name ^ "_blank_detection",
    max_blank=max_blank,
    min_noise=min_noise,
    start_blank=true,
    track_sensitive=false,
    on_noise = {
      log(name ^ " noisy")
      blank_ref := false;
    },
    {
      log(name ^ " silent")
      blank_ref := true;
    },
    source
  )

  # assure activation so blank detection works
  output.dummy(src, id="blank_detection_dummy_" ^ name)
  src
end

divog_a_blank = ref true
divog_b_blank = ref true
moderation_blank = ref true

divog_a = blank_detecter("divog_a", divog_a_blank, divog_a_input)
divog_b = blank_detecter("divog_b", divog_b_blank, divog_b_input)
moderation = blank_detecter("moderation", moderation_blank, moderation_input)

source_name = interactive.string("active_source", "a")

switched = switch(
  track_sensitive=false,
  [
    (
      {
        (not !moderation_blank) and (source_name() == "mod")
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
  url="https://entropia.de/GPN20",
  name="DiVOG",

  host=main_ice_host,
  port=main_ice_port,
  user=main_ice_user,
  password=main_ice_pass,
  mount=main_ice_mount,

  %mp3.cbr(
    internal_quality=6,
    bitrate=192
  ),
  switched
)
