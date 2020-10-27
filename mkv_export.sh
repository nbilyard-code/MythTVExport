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
# To use this script, you call it directly. (e.g. sh mkv_export.sh)
# You will need to install handbrake-cli inorder to use.  (e.g. sudo apt install handbrake-cli)
#
# REQUIREMENTS
# handbrake-cli
# ffmpeg
#
#   ###  Setting system variables ###
#
# Set the directory to export the files to, and the mythtv recording directory, plus a temp directory.
# Only the export and temp directorys need to be writeable to whomever is calling calling the file. (i.e. mythtv, your_user_name)
EXPORT_DIR="/media/server/Mythtranscode"
RECORD_DIR="/var/lib/mythtv/recordings"
TEMP_DIR="/media/server/tmp"

#    # Attempting to Fix files that fail #  UNDER CONSTRUCTION
# Somtimes the mythtranscode will fail, and will not output a file to the tmp folder for handbrake to encode.
# When this happens, the script will continue to the next file, but you will still lose the processor time,
# as the error won't showup until after the commercial flag.
# Once you have run the script on all your files, you can then try to go back and retry the files that did not encode
# To do this add "fix-broken" agrugment to the call of the script.  (e.g. sh mkv_export.sh fix-broken )
# The script will loop through all the files again, and if there is no mkv file in the output directory
# it will call ffmpeg to remux the original file, replace it, rebuild the index, then start the comflag process
# again.
# This WILL delete the original file, and replace it with a new copy.

# Set MYSQL information
# You can find the database info in your /etc/mythtv/config.xml file.  Put the password into the
# export MYSQL_PWD variable.  This keeps mysql from complaining about passwords in the clear.
export MYSQL_PWD=V3yZMrw9
user='mythtv'
host='localhost'
db='mythconverg'

# fix video variable
fix=$1

#  SCRIPT ############
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
	# Attempt to Fix a video that wont encode.	
	elif [[ ! -f "$test" && "fix" == "fix-broken" ]]; then
		ffmpeg -i "$file" -acodec copy -vcodec copy "$file"-new
		rm "$file"
		mv "file"-new "$file"
		mythtranscode --mpeg2 --buildindex --allkeys --showprogress --infile "$file"
	
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

