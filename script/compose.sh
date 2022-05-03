#!/bin/bash
if [ "$1" = "up" -o "$1" = "u" ]
then
    cmd="up -d"
elif [ "$1" = "down" -o "$1" = "d" ]
then
    cmd="down"
elif [ "$1" = "restart" -o "$1" = "r" ]
then
    cmd="up -d --force-recreate ${2}"
fi

docker-compose --env-file ../SecBuzzerESM.env -f docker-compose.yml $cmd
