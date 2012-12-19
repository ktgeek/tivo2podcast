# -*- coding: utf-8 -*-
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

  MP4_INVALID_FILE_HANDLE = nil
  
  attach_function(:c_mp4_modify, :MP4Modify, [:string, :uint32, :uint32],
                  :MP4FileHandle)
  # Modify an existing mp4 file.
  #
  # MP4Modify is the first call that should be used when you want to modify
  # an existing mp4 file. It is roughly equivalent to opening a file in
  # read/write mode.
  #
  # Since modifications to an existing mp4 file can result in a sub−optimal
  # file layout, you may want to use MP4Optimize() after you have  modified
  # and closed the mp4 file.
  #
  # fileName:: pathname of the file to be modified.
  #
  # verbosity:: bitmask of diagnostic details the library should print to stdout
  # during its functioning.
  #
  # @return On success a handle of the target file for use in subsequent calls
  # to the library. On error, #MP4_INVALID_FILE_HANDLE.
  #
  # @see MP4SetVerbosity() for <b>verbosity</b> values.
  def Mp4v2.mp4_modify(filename, verbosity = 0)
    # Per mp4v2 documentation, flags is currently ignored, so we won't
    # even expose that to ruby and just pass it as 0 all the time.
    c_mp4_modify(filename, verbosity, 0)
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
