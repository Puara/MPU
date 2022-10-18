#!/bin/bash

sclang -D ~/Documents/default.scd
pd -noprefs -rt -jack -inchannels 2 -outchannels 2 ~/Documents/default.pd
aj-snapshot -d ~/Documents/default.connections
