#!/bin/bash
#
# This bash script is for exporting all your mythtv recording as h264 mkv files to a new directory,
# and renaming the new encoded files in a human readable format.  This script has been tested on mythtv v31.
# The tested files were recoreded with a InfiniTV PCI using a cablecard to decode, and were a mix of mpg and ts files.
#
# The script will query the mythtv database, and pull out the name of the show, the show title, season, and episode
# number.  It will use the file name to run a mysql SELECT query on the mythconverg database recorded table. The script
# will NOT change your database nor will it delete or modify the original recording.  The script assumes that the mythtv recordings
# are in the default naming format of xxxx_yyyymmddssmmmm.extension (chanid_starttimeUTF)
#
# The script will use HandBrakeCLI to encode the video, and will keep looping though all the files until complete.
# This script is meant to loop through all the files in the recoreded directory and transcode all files that end in .mpg or .ts.
# It will check to see if a show has been exported first, and will not re-export if it already exists in the export directory.
# You can change the number of threads to use by editing the threads statement in the Handbrake command.  It is currently
# set to use 5 threads.
#
# To use this script, you call it directly.  It takes no arguments from the command line.
# You will need to install handbrake-cli inorder to use.  (e.g. sudo apt install handbrake-cli)
#
#
#   ###  Setting system variables ###
#
# Set the directory to export the files to, and the mythtv recording directory, plus a temp directory.
# Only the export and temp directorys need to be writeable to whomever is calling calling the file. (i.e. mythtv, your_user_name)
EXPORT_DIR="/media/server/Mythtranscode"
RECORD_DIR="/var/lib/mythtv/recordings"
TEMP_DIR="/media/server/tmp"

#    # Run as a cron job #
# If you want to run this script as a cron job, and only want it to run a set number of transcodes before it exits,
# please set the maximum number of transcode jobs to do before exiting as an argument in the cron job.
maxjob=$1


# Set MYSQL information
# You can find the database info in your /etc/mythtv/config.xml file.  Put the password into the
# export MYSQL_PWD variable.  This keeps mysql from complaining about passwords in the clear.
export MYSQL_PWD=V3yZMrw9
user='mythtv'
host='localhost'
db='mythconverg'

#  SCRIPT #b
cd $RECORD_DIR

for file in *.mpg *.ts
	do
	# Get Database info on the file
	title=$(mysql -u $user -h $host -D $db -se "SELECT title FROM recorded WHERE basename='$file'")
	subtitle=$(mysql -u $user -h $host -D $db -se "SELECT subtitle FROM recorded WHERE basename='$file'")
	season=$(mysql -u $user -h $host -D $db -se "select season FROM recorded WHERE basename='$file'")
	episode=$(mysql -u $user -h $host -D $db -se "SELECT episode FROM recorded WHERE basename='$file'")
	
	# Set human readable name,  Title-Subtitle-Season-Episode, and final video extension
	name=$title-$subtitle-$season-$episode
	ext='mkv'
	
	#check if name exists in the destination directory.  If yes, skip transcode.  If not, start the transcode.
	test=$EXPORT_DIR/$name.$ext
	if [ -f "$test" ]; then
		echo "$test exists, skipping transcode."
	else
	# First we will run a new commercial detect on the video file
	/usr/bin/mythcommflag --method=7 -f $file
	
	# Next, we pull out the chanid and starttime from the default filename for mythutil to generate a commercial cutlist.
	chid=$(echo $file | cut -c1-4)
	stime=$(echo $file | cut -c6-19)
	/usr/bin/mythutil --chanid "$chid" --starttime "$stime" --gencutlist
	/usr/bin/mythutil --chanid "$chid" --starttime "$stime" --getcutlist
	
	# Next, we transcode lossless with mythtranscode, cutting out the commercials.  The new video file and map are saved to the temp folder.
	/usr/bin/mythtranscode --chanid="$chid" --starttime "$stime" --mpeg2 --honorcutlist -o "$TEMP_DIR"/"$file"
	
	# Now we are ready to transcode to h264 with handbrake. 
	# Below you can edit the transcode options for Handbrake.  There are alot of options, so please check handbrake's documentation.
	/usr/bin/HandBrakeCLI -i "$TEMP_DIR"/"$file" -o "$EXPORT_DIR"/"$name"."$ext" -e x264 -q 20 -B 160 -x --comb-detect -d threads=5
	
	# Finally, we delete our temporary working files.
	rm "$TEMP_DIR"/"$file"
	rm "$TEMP_DIR"/"$file".map
	fi
done

