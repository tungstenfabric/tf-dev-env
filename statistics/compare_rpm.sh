#!/bin/sh
function compare_images_rpms() {
	image1=$1

	image2=$2
	tmp_file1="tmp1"
	tmp_file2="tmp2"
	local args='--rm --entrypoint rpm'
	opts="-qa --qf '%{NAME}\n' "
	echo "docker run $args $image1 $opts | sort  > $tmp_file1"
	echo "docker run $args $image2 $opts | sort > $tmp_file2"
	docker run $args $image1 $opts | sort | sed "s/'//g" > $tmp_file1
	docker run $args $image2 $opts | sort | sed "s/'//g" > $tmp_file2
	image_tag1=$( docker inspect  -f "{{ .RepoTags }}" $image1 )
        image_tag2=$( docker inspect  -f "{{ .RepoTags }}" $image2 )
	echo "RPMs in $image_tag1 only:"
	comm -23 "$tmp_file1" "$tmp_file2"

	echo
	echo "RPMs in $image_tag2 only:"
	comm -13 "$tmp_file1" "$tmp_file2"
	rm -rf "$tmp_file1" "$tmp_file2"

}
