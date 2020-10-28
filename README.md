# MythTVExport
Bash script to loop and export MythTV Recordings to external directory.  Remove Commercials and transcode a new copy to h264.

This bash script is for exporting all your mythtv recording as h264 mkv files to a new directory,
and renaming the new encoded files in a human readable format.  This script has been tested on mythtv v31.
The tested files were recoreded with a InfiniTV PCI using a cablecard to decode, and were a mix of mpg and ts files.

The script will query the mythtv database, and pull out the name of the show, the show title, season, and episode
number.  It will use the file name to run a mysql SELECT query on the mythconverg database recorded table. The script
will NOT change your database nor will it delete or modify the original recording.  The script assumes that the mythtv recordings
are in the default naming format of xxxx_yyyymmddssmmmm.extension (chanid_starttimeUTF)

The script will use HandBrakeCLI to encode the video, and will keep looping though all the files until complete.
This script is meant to loop through all the files in the recoreded directory and transcode all files that end in .mpg or .ts.
It will check to see if a show has been exported first, and will not re-export if it already exists in the export directory.
You can change the number of threads to use by editing the threads statement in the Handbrake command.  It is currently
set to use 5 threads.

To use this script, you call it directly. (e.g. sh mkv_export.sh)
You will need to install handbrake-cli inorder to use.  (e.g. sudo apt install handbrake-cli)

# REQUIREMENTS
handbrake-cli
mythcommflag
mythtranscode
mythutils

# Setting system variables

Set the directory to export the files to, and the mythtv recording directory, plus a temp directory.
Only the export and temp directorys need to be writeable to whomever is calling calling the file. (i.e. mythtv, your_user_name)
EXPORT_DIR="/media/server/Mythtranscode"
RECORD_DIR="/var/lib/mythtv/recordings"
TEMP_DIR="/media/server/tmp"

# Attempting to fix files that fail  
Sometimes the mythtranscode will fail, and will not output a file to the tmp folder for handbrake to encode.
When this happens, the script will continue to the next file, but you will still lose the processor time,
as the error won't showup until after the commercial flag.  This error seems to occur more for .ts files in my case.
Once you have run the script on all your files, you can then try to go back and retry the files that did not encode
To do this add "encode-broken" argument to the call of the script.  (e.g. sh mkv_export.sh encode-broken )
The script will loop through all the files again, and if there is no mkv file in the output directory
it will try to run handbrake-cli on the original file with no commercial flagging or cutting.
