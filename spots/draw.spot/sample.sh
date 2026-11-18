#!/bin/sh
# The sheet of Draw over three boards, as `Sheet` prints it. The test `testTheSampleIsTheSheetOverSampleBoards` compares the two.
printf 'frame=\nrecents=false\n\n'
printf 'button=open\ntitle=Open\nclose=true\n\n'
printf 'button=0:new\ntitle=New board\nshortcut=cmd+n\nscope=spot\nclose=true\n\n'
printf 'button=rename\ntitle=Rename\nshortcut=cmd+r\nform=true\n\n'
printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to move it to the Trash\n\n'
printf 'button=reveal\ntitle=Show boards in Finder\nshortcut=cmd+o\nscope=spot\n\n'
printf 'row=0:new\ntitle=New board\ndetail=A blank board\nicon=plus.square.dashed\nhides=rename\nhides=delete\n\n'
printf 'row=0:flows\ntitle=Sign-up flow\ndetail=Edited 3 min ago\nicon=scribble.variable\n\n'
printf 'row=0:launch\ntitle=Launch plan\ndetail=Edited 3 h ago\nicon=scribble.variable\n\n'
printf 'row=0:Work/roadmap\ntitle=Roadmap\ndetail=Work · Edited yesterday\nicon=scribble.variable\n'
