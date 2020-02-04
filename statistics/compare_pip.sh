#!/bin/sh
function compare_images_pip() {
	local image1=$1
	local image2=$2
        local python_ent=$3
	local tmp_file1="tmp1"
	local tmp_file2="tmp2"
	local args="--rm --entrypoint $python_ent "
	opts=" -m pip list "
	docker run $args $image1 $opts | awk '{print $1}' | sort  > $tmp_file1
	docker run $args $image2 $opts | awk '{print $1}' | sort  > $tmp_file2
	image_tag1=$( docker inspect  -f "{{ .RepoTags }}" $image1 | tr -d '[]' )
        image_tag2=$( docker inspect  -f "{{ .RepoTags }}" $image2 | tr -d '[]' )
	echo "pip $python_ent libs in $image_tag1 only:"
	comm -23 "$tmp_file1" "$tmp_file2"

	echo
	echo "pip $python_ent libs in $image_tag2 only:"
	comm -13 "$tmp_file1" "$tmp_file2"
	rm -rf "$tmp_file1" "$tmp_file2"

}
