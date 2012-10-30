require 'ffi'

# This module uses FFI to wrap the mp4v2 functions needed by the
# TiVo2Podcast script.
module Mp4v2
  extend FFI::Library

  # Behind the scenes in C land this is using dlopen, so library path
  # semantics from there will be followed
  ffi_lib ['libmp4v2']

  typedef :pointer, :MP4FileHandle
  typedef :uint32, :MP4TrackId
  typedef :uint64, :MP4Duration

  attach_function(:c_mp4_modify, :MP4Modify, [:string, :uint32, :uint32],
                  :MP4FileHandle)
  def Mp4v2.mp4_modify(filename, verbosity = 0, flags = 0)
    c_mp4_modify(filename, verbosity, flags)
  end

  attach_function(:c_mp4_optimize, :MP4Optimize, [:string, :string, :uint32],
                  :bool)
  def Mp4v2.mp4_optimize(filename, new_filename = nil, verbosity = 0)
    c_mp4_optimize(filename, new_filename, verbosity)
  end

  attach_function(:c_mp4_add_chapter_text_track, :MP4AddChapterTextTrack,
                  [:MP4FileHandle, :MP4TrackId, :uint32], :MP4TrackId)
  def Mp4v2.mp4_add_chapter_text_track(h_file, ref_track_id, timescale = 0)
    c_mp4_add_chapter_text_track(h_file, ref_track_id, timescale)
  end
  
  attach_function(:c_mp4_add_chapter, :MP4AddChapter,
                  [:MP4FileHandle, :MP4TrackId, :MP4Duration, :string], :void)
  def Mp4v2.mp4_add_chapter(h_file, chapter_track_id, chapter_duration,
                            chapter_title = nil)
    c_mp4_add_chapter(h_file, chapter_track_id, chapter_duration, chapter_title)
  end
  
  attach_function :mp4_close, :MP4Close, [:MP4FileHandle], :void
end
