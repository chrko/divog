%include "icecast_credentials.liq"
%include "common-settings.liq"
%include "funcs.liq"

set("log.file.path", "/home/divog/liquidsoap-switch.log")
set("server.telnet.port", 9000)

# restart persistent source selection
default_source = "a"
persistence_file = "/home/divog/divog-switch.persistence"

active_source = ref default_source

def read_active_source(~shutdown_on_error=false)
  if file.exists(persistence_file) then
    if not file.is_directory(persistence_file) then
      contents = file.contents(persistence_file)
      contents = string.sub(contents, start=0, length=1)
      active_source := contents
      true
    else
      print("divog " ^ "persistence_file " ^ persistence_file ^ " exists but is not an file")
      if shutdown_on_error then
        shutdown()
      end
      false
    end
  else
    print("divog " ^ "persistence_file " ^ persistence_file ^ " doesn't exist (yet)")
    false
  end
end

def store_active_source()
  # res = file.write(!active_source, persistence_file)
  res = test_process(
    timeout=1.,
    "echo \"" ^ !active_source ^ "\" > " ^ persistence_file
  )
  if not res then
    print("divog " ^ "unabled to write persistence file " ^ persistence_file)
  end
  res
end

# initially write persistence_file
if not read_active_source(shutdown_on_error=true) then
  if not store_active_source() then
    shutdown()
  end
end

# watch for changes of the file
watcher = file.watch(
  persistence_file,
  {
    if read_active_source() then
      print("file changed!")
    end
  }
)

# fallback source
# TODO: Currently only silence, some other audio available?
fallback_audio = blank(id="fallback_source")

# create safe and stereo audio only inputs
divog_a_input = in_http("divog_a", "http://localhost/input-a")
divog_b_input = in_http("divog_b", "http://localhost/input-b")
moderation_input = in_http("moderation", "http://localhost/mod")

# continuously dump input streams
dump("divog_a_input", divog_a_input)
dump("divog_b_input", divog_b_input)

# blank detection function
# blank_detecter :
#  (string,ref(bool),source(audio='#a,video='#b,midi='#c),?max_blank:float,
#   ?min_noise:float)->source(audio='#a,video='#b,midi='#c)
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
  # blank detection needs an active source but doesn't activate the source itself so we activate it with force
  output.dummy(src, id="blank_detection_dummy_" ^ name)
  src
end

# references for blank detection
divog_a_blank = ref true
divog_b_blank = ref true
moderation_blank = ref true

# create blank detections on every input
divog_a = blank_detecter("divog_a", divog_a_blank, divog_a_input)
divog_b = blank_detecter("divog_b", divog_b_blank, divog_b_input)
moderation = blank_detecter("moderation", moderation_blank, moderation_input, max_blank=10.)

def transition(a,b)
  add(normalize=false,
      [ fade.in(duration=3.,b),
        fade.out(duration=3.,a) ])
end

# main switching function
switched = switch(
  track_sensitive=false,
  transitions=[transition],
  [
    (
      {
        (not !moderation_blank) and (!active_source == "m")
      },
      moderation
    ),
    (
      {
        (not !divog_a_blank) and (!active_source == "a")
      },
      divog_a
    ),
    (
      {
        (not !divog_b_blank) and (!active_source == "b")
      },
      divog_b
    ),
    ({true}, fallback_audio)
  ],
  id="divog_switch"
)

# output section
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
