/*
 * Copyright 2011 Keith T. Garner. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 */
#include <fstream>
#include <string>
#include <boost/lexical_cast.hpp>
#include <boost/regex.hpp>
#include <mp4v2/mp4v2.h>

int main(int argc, char *argv[])
{
    char *m4vfilename = argv[1];
    char *chapfilename = argv[2];
    int total_length = boost::lexical_cast<int>(argv[3]);

    std::ifstream chapfile(chapfilename);

    MP4FileHandle m4vfile = MP4Modify(m4vfilename);

    // Add the chapter track, have it reference the first track
    // (should be the video) and set the "clock ticks per second" to 1.
    // (We may want to set that to 1000 to go into milliseconds.)
    MP4TrackId chapter_track = MP4AddChapterTextTrack(m4vfile, 1, 1);

    boost::regex chpre("^AddChapterBySecond\\((\\d+),");
    boost::smatch rem;
    std::string s;
    int last_time = 0;
    while (getline(chapfile, s))
    {
        if (boost::regex_search(s, rem, chpre))
        {
            int t = boost::lexical_cast<int>(rem[1]);
            if (t > 0)
            {
                MP4AddChapter(m4vfile, chapter_track, t - last_time);
                last_time = t;
            }
        }
    }

    if (total_length - last_time > 0)
    {
        MP4AddChapter(m4vfile, chapter_track, total_length - last_time);
    }

    MP4Close(m4vfile);
    MP4Optimize(m4vfilename);

    return 0;
}
