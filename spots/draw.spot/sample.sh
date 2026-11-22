#!/bin/sh
# The sheet of Draw over three boards, as `Sheet` prints it. The test `testTheSampleIsTheSheetOverSampleBoards` compares the two.
printf 'frame=\nrecents=false\n\n'
printf 'button=press\ntitle=Open\n\n'
printf 'button=0:new\ntitle=New board\nshortcut=cmd+n\nscope=spot\n\n'
printf 'button=rename\ntitle=Rename\nshortcut=cmd+r\nform=true\nclose=false\n\n'
printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to move it to the Trash\nclose=false\n\n'
printf 'button=reveal\ntitle=Show boards in Finder\nshortcut=cmd+o\nscope=spot\n\n'
printf 'item=0:new\ntitle=New board\ndetail=A blank board\nicon=plus.square.dashed\nhides=rename\nhides=delete\n\n'
printf 'item=0:flows\ntitle=Sign-up flow\ndetail=Edited 3 min ago\nicon=scribble.variable\n\n'
printf 'item=0:launch\ntitle=Launch plan\ndetail=Edited 3 h ago\nicon=scribble.variable\n\n'
printf 'item=0:Work/roadmap\ntitle=Roadmap\ndetail=Work · Edited yesterday\nicon=scribble.variable\n'
