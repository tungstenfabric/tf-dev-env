#!/bin/bash
set +x
function get_size() {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local size=$(docker inspect -f "{{ json .Size }}" $image_id)
        size=$(( size / 1000000 ))
        echo $size
    fi
}

function get_layers_count () {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local layers=$( docker history $image_id | wc -l )        
        echo $layers
    fi
}

function get_layers_size() {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local layers=$( docker history $image_id | grep MB )
        
        echo "$layers MB"
    fi
}


function run_ct_bash() {
	local image_id=$1
	if [[ -n "${image_id}" ]]; then
		local ct_id=$( docker run -d --entrypoint bash $image_id )
		local exit_code="$?"
		if [ "${exit_code}" -eq 0 ] ; then
			echo "$ct_id"
		else
			echo "Could not start container with image "
			exit 1
		fi
		
	fi

}

function get_image_tag() {
	local image_id=$1
	local image_tag=$( docker inspect  -f "{{ .RepoTags }}" ${image_id} | tr -d '[]' | awk '{ print $1 }' )
	echo "$image_tag"
} 



function compare_fs() {
	local im_id_1=$1
	local im_id_2=$2
	local image_tag_1=$( get_image_tag $im_id_1 )
	local image_tag_2=$( get_image_tag $im_id_2 )
	local dirrr="./tmp_logs_$(date +%m-%d-%Y-%H-%M-%S)"
	mkdir -p "$dirrr"
	pushd $dirrr
	local tmp_file_1="./tmp1"
	local tmp_file_2="./tmp2"
	local tmp_file_1_size="${tmp_file_1}_${im_id_1}_size"
	local tmp_file_2_size="${tmp_file_2}_${im_id_2}_size"
	local stats_file="./stats_$1_$2"
	touch $stats_file
	echo "Start collecting stats for ${image_tag_1} and ${image_tag_2} " > "$stats_file"
	if [[ -n "${im_id_1}" &&  -n "${im_id_2}" ]] ; then
		#local ct_id_1=$( run_ct_bash $im_id_1 )
		#local ct_id_2=$( run_ct_bash $im_id_2 )
		#local full_path_1=$( docker inspect -f "{{ .ResolvConfPath }}" $ct_id_1 )
		#local dir_path_1=$( dirname $full_path_1 )
		#local full_path_2=$( docker inspect -f "{{ .ResolvConfPath }}" $ct_id_2 )
                #local dir_path_2=$( dirname $full_path_2 )
		#echo "full_path_1 is $full_path_1"
		#echo "full_path_2 is $full_path_2"
		#dir_path_1=
		#find "$dir_path_1" -xdev | sort > "$tmp_file_1"
		#find "$dir_path_2" -xdev | sort > "$tmp_file_2"
		docker run --rm --entrypoint find $im_id_1 / -xdev -printf "%h/%f , %s\n" | sort -r -t, -nk2 > "${tmp_file_1_size}" 
		docker run --rm --entrypoint find $im_id_2 / -xdev -printf "%h/%f , %s\n" | sort -r -t, -nk2 > "${tmp_file_2_size}"
		docker run --rm --entrypoint find $im_id_1 / -xdev | sort > "${tmp_file_1}"
                docker run --rm --entrypoint find $im_id_2 / -xdev  | sort  > "${tmp_file_2}"
		#diff -daU 0 $tmp_file_1 $tmp_file_2 | grep -vE '^(@@|\+\+\+|---)' > "stats_debug_$1_$2"

		for i in $(seq 1 5); do echo "###########################" >> $stats_file; done
	        echo "files in $image_tag_1  only:" >> $stats_file
		for i in $(seq 1 5); do echo "###########################" >> $stats_file; done

	        comm -23 $tmp_file_1 $tmp_file_2  > "./tmp1_diff"
		while read FILE; do
		  local file_size=$(grep -e "$FILE" "${tmp_file_1_size}" )
		  echo "$image_tag_1: $file_size" >> "./tmp1_diff_size"
		done <  "./tmp1_diff"
		sort  -r -t, -nk2 ./tmp1_diff_size >>  $stats_file
		rm -rf ./tmp1_diff ./tmp1_diff_size

        	echo
		echo

		for i in $(seq 1 5); do echo "###########################" >> $stats_file; done
	        echo "files in $image_tag_2 only:" >> $stats_file
		for i in $(seq 1 5); do echo "###########################" >> $stats_file; done

		comm -13 $tmp_file_1 $tmp_file_2  > "./tmp2_diff"

                while read FILE; do
                  local file_size=$(grep -e "$FILE" "${tmp_file_2_size}" )
                  echo "$image_tag_2: $file_size" >> "./tmp2_diff_size"
                done <  "./tmp2_diff"
                sort  -r -t, -nk2 ./tmp2_diff_size >>  $stats_file
                rm -rf ./tmp2_diff ./tmp2_diff_size

		#rm -rf $tmp_file_1 $tmp_file_2

	fi
	popd
}
