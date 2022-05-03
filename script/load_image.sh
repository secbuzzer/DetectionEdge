#/bin/bash

IMAGE_NAME=`find ../images/ -type f -name *.tar`

for data in $IMAGE_NAME; do
	docker load  -i $data
done
