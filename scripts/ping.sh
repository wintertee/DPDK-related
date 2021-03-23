# auto reboot when loss internet connection

ping_count=0
while :
do
    sleep 10
    if ping -c 1 baidu.com
    then
        if [ "$ping_count" -gt 0 ]
        then
            ((--ping_count))
        fi
    else
        ((++ping_count))
    fi

    if [ "$ping_count" -gt 3 ]
    then
        sudo reboot
    fi
done
