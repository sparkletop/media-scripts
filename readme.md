# Media scrips

This repo contains various convenience scripts for archiving and batch-processing audiovisual media and optical media (CD/DVD). Scripts are written in bash and python and developed for use in linux.

The scripts are not tested in any rigorous way, so they probably shouldn't be used in production.

## The scripts

- *2m4a.sh* - convert and compress audio file using the aac codec and a .m4a container
- *2ogg.sh* - convert and compress audio file using the libvorbis codec and a .ogg container
- *dffmpeg.sh* - run ffmpeg in a docker container from linuxserver.io
- *autorename.py* - script to monitor a directory for changes and rename sequentially after a grace period with no changes
- *cddvd2iso.sh* - archive a CD or DVD to a .iso-file
