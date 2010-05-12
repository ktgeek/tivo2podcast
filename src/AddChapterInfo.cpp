#include <fstream>
#include <string>
#include <boost/lexical_cast.hpp>
#include <boost/regex.hpp>
#include <mp4v2/mp4v2.h>

// g++  AddChapterInfo.cpp -o AddChapterInfo -I/opt/local/include -L/opt/local/lib -lmp4v2 -lboost_regex

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

    boost::regex chpre("^AddChapterBySecond\\((\\d+),(\\w+\\s+\\w+)\\)");
    boost::smatch rem;
    std::string s;
    int last_time = 0;
    while (getline(chapfile, s))
    {

        if (boost::regex_search(s, rem, chpre))
        {
            int t = boost::lexical_cast<int>(rem[1]);
            MP4AddChapter(m4vfile, chapter_track, t - last_time, rem[2].str().c_str());
            last_time = t;
        }
    }

    MP4AddChapter(m4vfile, chapter_track, total_length - last_time);

    MP4Close(m4vfile);
    //    MP4Optimize("test.m4v", "final.m4v");

    return 0;
}
