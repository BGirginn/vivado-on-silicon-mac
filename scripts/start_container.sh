#!/bin/zsh

# starts the Docker container and xvcd for USB forwarding

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_macos

# this is called when the container stops or ctrl+c is hit
function stop_container {
    docker kill vivado_container > /dev/null 2>&1
    f_echo "Stopped Docker container"
    killall xvcd > /dev/null 2>&1
    f_echo "Stopped xvcd"
    exit 0
}
trap 'stop_container' INT

# Make sure everything is setup to run the container
start_docker
if [[ $(docker ps) == *vivado_container* ]]
then
    f_echo "There is already an instance of the container running."
    exit 1
fi
killall xvcd > /dev/null 2>&1

# run container
mkdir -p "$HOME/.claude"
docker run --init --rm --name vivado_container --mount type=bind,source="$script_dir/..",target="/home/user" --mount type=bind,source="$HOME/.claude",target="/home/user/.claude" -p 127.0.0.1:5901:5901 --platform linux/amd64 x64-linux sudo -H -u user bash /home/user/scripts/linux_start.sh &
f_echo "Started container"
sleep 7
f_echo "Starting VNC viewer"
if open -a "TigerVNC" "vnc://localhost:5901" 2>/dev/null; then
    :
else
    vncpass=$(tr -d "\n\r\t " < "$script_dir/vncpasswd")
    open "vnc://user:$vncpass@localhost:5901"
fi
f_echo "Open a new terminal tab and run: zsh $script_dir/attach.sh"
f_echo "Running xvcd for USB forwarding..."
# while vivado_container is running
while [[ $(docker ps) == *vivado_container* ]]
do
    # if there is a running instance of xvcd
    if pgrep -x "xvcd" > /dev/null
    then
        :
    else
        eval "$script_dir/xvcd/bin/xvcd > /dev/null 2>&1 &"
        sleep 2
    fi
done
stop_container
