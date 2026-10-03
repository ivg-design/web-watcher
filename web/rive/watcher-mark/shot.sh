#!/bin/sh
# usage: shot.sh name advance [--data=...]
n=$1; a=$2; shift 2
rive "$(dirname "$0")" --quiet --screenshot=build/$n.png --advance=$a --viewport=384x384 --fit=contain "$@"
