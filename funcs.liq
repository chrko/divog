def dump(name_base, source)
  file_name = "/home/divog/recordings/" ^ name_base ^ "/%Y-%m-%d/%H-%M-%S.mp3"
  output.file(
    id=name_base ^ "_dump",
    %mp3(
      bitrate=192
    ),
    reopen_when={0m},
    file_name,
    source
  )
end

def in_http(name, url)
  in = input.http(url, id=name ^ "_input_http")
  clean = audio_to_stereo(
    id="z_audio_to_stereo_" ^ name,
    drop_video(
      id="z_drop_video_" ^ name,
      drop_midi(
        id="z_drop_midi_" ^ name,
        in
      )
    )
  )
  mksafe(
    id=name ^ "_safe_input",
    clean
  )
end
