#!/bin/bash
#
# This bash script is for exporting all your mythtv recording as h264 mkv files to a new directory,
# and renaming the new encoded files in a human readable format.  This script has been tested on mythtv v31.
#
# The script will query the mythtv database, and pull out the name of the show, the show title, season, and episode
# number.  It will use the file name to run a mysql SELECT query on the mythconverg database recorded table. The script
# will NOT change your database nor will it delete or modify the original recording.
#
# The script will use HandBrakeCLI to encode the video, and will keep looking though all the files until complete.
# This script is meant to loop through all the files in the recoreded directory and transcode all files that end in .mpg or .ts.
# It will check to see if a show has been exorted, and will not re-export if it already exists in the exort directory.
# You can change the number of threads to use by editing the threads statement in the Handbrake command.  It is currently
# set to use 4 threads.
#
# To use this script, you can call it directly or run it as a cron job.  It takes no arguments from the command line.
# You will need to install handbrake-cli inorder to use.  (e.g. sudo apt install handbrake-cli)
#
#
# Set the directory to export the files to, and the mythtv recording directory
EXPORT_DIR="/media/server/Mythtranscode"
RECORD_DIR="/var/lib/mythtv/recordings"
# Set MYSQL information
# You can find the database info in your /etc/mythtv/config.xml file.  Put the password into the
# export MYSQL_PWD variable.  This keeps mysql from complaining about passwords in the clear.
export MYSQL_PWD=V3yZMrw9
user='mythtv'
host='localhost'
db='mythconverg'

cd $RECORD_DIR
for file in *.mpg *.ts
	do
	title=$(mysql -u $user -h $host -D $db -se "SELECT title FROM recorded WHERE basename='$file'")
	subtitle=$(mysql -u $user -h $host -D $db -se "SELECT subtitle FROM recorded WHERE basename='$file'")
	season=$(mysql -u $user -h $host -D $db -se "select season FROM recorded WHERE basename='$file'")
	episode=$(mysql -u $user -h $host -D $db -se "SELECT episode FROM recorded WHERE basename='$file'")
	name=$title-$subtitle-$season-$episode
	ext='mkv'
	test=$EXPORT_DIR/$name.$ext
	if [ -f "$test" ]; then
		echo "$test exists, skipping transcode."
	else
	# Below you can edit the transcode options in Handbrake.  There are alot of options, so please check handbrake's documentation.
	/usr/bin/HandBrakeCLI -i $file -o "$EXPORT_DIR"/"$name"."$ext" -e x264 -q 20 -B 160 -x --comb-detect -d threads=4
	fi
done

