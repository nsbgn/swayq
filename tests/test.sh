#!/bin/sh
# TODO This should be done in Go

cd "$(dirname "$0")"
export WLR_BACKENDS=headless WLR_RENDERER=pixman LIBSEAT_BACKEND=noop WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK=/run/user/1000/swayq-test SWAYQ_DEBUG=1

# cf. <https://stackoverflow.com/questions/360201/how-do-i-kill-background-processes-jobs-when-my-shell-script-exits>
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

for JQFILE in *_test.jq; do
    if [ -f "${JQFILE%.jq}.conf" ]; then
        sway -c "${JQFILE%.jq}.conf" 2>/dev/null &
    else
        sway -c /dev/null 2>/dev/null &
    fi
    sleep 0.1
    for TEST in $(sed -n 's/^def \(.*_test\):/\1/p' "$JQFILE"); do
        echo -e -n "\033[1;4m$JQFILE:$TEST\033[0m"
        echo -e "\033[90m"
        swayq "$JQFILE" "$TEST" > /dev/null
        if [ "$?" != 0 ]; then
            echo -e "\033[0;31;1mFail\033[0m"
        else
            echo -e "\033[0;32;1mSuccess\033[0m"
        fi
    done
    swaymsg -q exit 2> /dev/null
done
sleep 1
