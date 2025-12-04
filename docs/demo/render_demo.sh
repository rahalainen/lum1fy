#!/bin/bash
# Demo video renderer for lum1fy

# check and download demo video
if [ ! -f and-ever.mp4 ]; then
    echo "Downloading asset for demo..."
    curl -L -o and-ever.mp4 "https://femboy.beauty/pBd5Z1"
fi

# run VHS after download is done
vhs lum1fy.tape
