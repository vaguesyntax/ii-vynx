#!/usr/bin/env bash

git pull
sleep 0.1

pkill qs
sleep 0.5

pkexec /usr/local/bin/vynx update
qs -c ii