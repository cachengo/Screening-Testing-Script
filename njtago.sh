#!/bin/bash
B1IPS=(
    10.10.1.190
    10.10.1.191
    10.10.1.192
    10.10.1.193
    10.10.1.194
    10.10.1.195
    10.10.1.196
    10.10.1.197
)

CAM=(
    #input the camera URL
)

B2IPS=(
    10.10.1.198
    10.10.1.199
    10.10.1.200
    10.10.1.201
    10.10.1.202
    10.10.1.203
    10.10.1.204
    10.10.1.205
)

LCT=(
    111
    112
    113
    114
    121
    122
    123
    124
)

B1TL=b1_test_log.txt
B2TL=b2_test_log.txt
B1MS=b1min_size.txt
B2MS=b2min_size.txt
TME="date +%H:%M:%S"
DATE="date +%s -d '4 min ago'"

email() {
    mail -s 'NJTA Test Failure' mjackson@cachengo.com <<<'There is a failure in the NJTA Test Bed'
}

agstat_check() {
    local -n IPS=$1
    local -n F1=$2
    NTME="`ssh -t cachengo@${IPS[i]} date`"
    for ((i = 0; i < ${#IPS[@]}; ++i)); do
        ssh -t cachengo@${IPS[i]} "sudo service argos status | grep inactive"
        if [ "$?" -eq 1 ]; then
            echo "$($TME) Argos service status is running"
        else
            echo "ERROR!!! FAILED Argos status at $($TME) node time $NTME in Node ${LCT[i]}" >>$F1
            email
            return 1
        fi
    done
}

minio_check() {
    local -n IPS=$1
    local -n F2=$2
    echo " " >>$F2
    echo "$TME" >>$F2
    for ((i = 0; i < ${#IPS[@]}; ++i)); do
        ssh -t cachengo@${IPS[i]} "echo " " >> $F2"
        ssh -t cachengo@${IPS[i]} "sudo du -sh /data" >>$F2
        ssh -t cachengo@${IPS[i]} "sudo du -s /data | tr -dc '0-9'" >>$F2
    done

}

m_cmp() {
    local -n IPS=$1
    local -n F1=$2
    local -n F2=$3
    NTME="ssh -t cachengo@${IPS[i]} date"
    for ((i = 0; i < ${#IPS[@]}; ++i)); do
        EC="$(ssh -t cachengo@${IPS[i]} "tail -n 1 $F2")"
        NC="$(ssh -t cachengo@${IPS[i]} "sudo du -s /data | tr -dc '0-9'")"
        if [ "$NC" -lt "$EC" ]; then
            echo "good"
        else
            echo "ERROR!!! FAILED Minio Compare at $($TME) node time $NTME in Node ${LCT[i]}" >>$F1
            email
            return 1
        fi
    done
}

vid_check() {
    local -n IPS=$1
    local -n F1=$2
    for ((i = 0; i < ${#CAM[@]}; ++i)); do
        if [[ $(curl --request GET --url '${CAM[i]}'"$DATE"'' | grep "EXTINF:") ]]; then
            echo "Camera is runnin"
        else
            echo "ERROR!!! FAILED Video Check at $($TME) for Video ${CAM[i]}" >>$F1
            email
            return 1
        fi
    done
}


while : do
    echo " " >>$B1TL
    echo "$($TME) - Test start" >>$B1TL
    echo " " >>$B2TL
    echo "$($TME) - Test start" >>$B2TL
    minio_check B1IPS B1MS
    sleep 15
    curl -u cachengo:m http://10.10.1.10/outlet?6=OFF # Turning off B2
    echo "$($TME) - Bus 2 tuned off" >>$B2TL
    curl -u cachengo:m http://10.10.1.10/outlet?5=ON # Truning ON Terminal for B1 pull in.
    echo "$($TME) - Bus 1 started uploading to Pizza 1" >>$B1TL
    sleep 900
    curl -u cachengo:m http://10.10.1.10/outlet?5=OFF # Truning off Terminal for B1 pull away.
    echo "$($TME) - Bus 1 stop uploading to Pizza 1" >>$B1TL
    curl -u cachengo:m http://10.10.1.10/outlet?6=ON # Turning ON B2.
    echo "$($TME) - Bus 2 tuned on" >>$B2TL
    sleep 360

    if ! agstat_check B1IPS B1TL; then break; fi #Checking Argos status in Bus 1
    sleep 540

    if ! m_cmp B1IPS B1TL B2MS; then break; fi #Comparing old data size to current data size   
    sleep 900

    if ! vid_check B1IPS B1TL; then break; fi #Checking Video processing on Bus 1 to make sure the video is still processing.
    sleep 900

    if ! agstat_check B2IPS B2TL; then break; fi #Checking Video processing on Bus 2 to make sure the video is still processing.
    sleep 900

    if ! vid_check B1IPS B1TL; then break; fi #Checking Video processing on Bus 1 to make sure the video is still processing.
    
    echo " " >>$B1TL
    echo "$($TME) - Test start" >>$B1TL
    echo " " >>$B2TL
    echo "$($TME) - Test start" >>$B2TL
    minio_check B2IPS B2MS #B2 MinIO check before unload#
    sleep 15
    curl -u cachengo:m http://10.10.1.10/outlet?7=OFF # Turning off B1 so B2 can pulling into the Terminal alone.#
    echo "$($TME) - Bus 1 tuned off" >>$B1TL
    curl -u cachengo:m http://10.10.1.10/outlet?5=ON # Truning ON Terminal for B2 pull in.#
    echo "$($TME) - Bus 2 started uploading to Pizza 1" >>$B2TL
    sleep 360
    curl -u cachengo:m http://10.10.1.10/outlet?5=OFF # Truning off Terminal for B2 pull away.#
    echo "$($TME) - Bus 2 stop uploading to Pizza 1" >>$B2TL
    curl -u cachengo:m http://10.10.1.10/outlet?7=ON # Turning ON B1.#
    echo "$($TME) - Bus 1 tuned on" >>$B1TL
    sleep 360
   
    if ! agstat_check B2IPS B2TL; then break; fi #Checking Argos status in Bus 1  
    sleep 540

    if ! m_cmp B2IPS B2TL B1MS; then break; fi #Comparing old data size to current data size   
    sleep 900

    if ! vid_check B2IPS B2TL; then break; fi #Checking Video processing on Bus 1 to make sure the video is still processing.
    sleep 900

    if ! agstat_check B1IPS B1TL; then break; fi #Checking Video processing on Bus 2 to make sure the video is still processing.
    sleep 900

    if ! vid_check B2IPS B2TL; then break; fi #Checking Video processing on Bus 1 to make sure the video is still processing.
done
