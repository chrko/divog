%include "common-settings.liq"
%include "funcs.liq"

set("log.file.path", "/home/divog/liquidsoap-live_dumper.log")
set("server.telnet.port", 9001)

dump(
  "divog_c_radar",
  in_http(
    "divog_c_radar",
    "http://stream.c-radar.de:8000/divog.mp3"
  )
)
