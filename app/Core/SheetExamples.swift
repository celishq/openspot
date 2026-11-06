import Foundation

/// A working sheet for each layout, for a person to start from in the sandbox and a model to read in the catalog.
public enum SheetExamples {
    public struct Example: Equatable, Sendable {
        public let name: String
        public let text: String
    }

    public static let all: [Example] = [
        Example(name: "pair", text: """
        layout=pair

        part=source
        cell=from
        option=auto:Automatic
        option=en:English
        value=auto

        part=input
        cell=top
        text=Good morning
        placeholder=Type or paste text

        part=target
        cell=to
        option=fr:French
        option=de:German
        value=fr

        part=output
        cell=bottom
        text=Bonjour
        readonly=true

        part=swap
        cell=swap
        press=arrow.up.arrow.down
        key=cmd+shift+s

        part=copy
        cell=action
        align=right
        look=chip
        title=Copy
        press=true
        key=cmd+return
        close=true

        """),
        Example(name: "media", text: """
        layout=media

        part=art
        cell=picture
        image=/System/Library/Desktop Pictures/.thumbnails/Sequoia.heic

        part=play
        cell=action
        look=strong
        press=pause.fill

        part=song
        cell=title
        title=Night drive
        detail=2:14 / 3:40

        part=position
        cell=seek
        level=60

        part=previous
        cell=back
        look=bare
        press=backward.fill

        part=following
        cell=next
        look=bare
        press=forward.fill

        """),
        Example(name: "job", text: """
        layout=job

        part=file
        cell=file
        title=Demo.mov
        detail=1.2 GB

        part=quality
        cell=left
        option=high:High quality
        option=low:Low quality
        value=high

        part=format
        cell=right
        align=right
        option=mp4:MP4
        value=mp4

        part=status
        cell=progress
        block=progress
        title=Converting
        detail=1:12 left
        level=62

        part=log
        cell=log
        text=frame= 4120 fps= 96\\nframe= 4216 fps= 97
        readonly=true

        part=stop
        cell=action
        align=right
        look=chip
        title=Stop
        press=true

        """),
        Example(name: "chat", text: """
        layout=chat

        part=messages
        cell=messages
        text=Why do the checks fail?\\n\\nThe build step cannot find the module.
        readonly=true

        part=question
        cell=input
        text=
        placeholder=Ask

        part=model
        cell=left
        align=left
        option=fast:Fast
        option=deep:Deep
        value=fast

        part=ask
        cell=send
        look=strong
        press=arrow.up
        key=cmd+return

        """),
        Example(name: "tiles", text: """
        layout=tiles

        part=cpu
        cell=one
        metric=42%
        title=CPU

        part=memory
        cell=two
        metric=61%
        title=Memory

        part=history
        cell=chart
        point=2
        point=4
        point=3
        point=6
        point=8
        point=5

        part=refresh
        cell=corner
        press=arrow.clockwise

        part=disk
        cell=three
        metric=312 GB
        title=Disk free

        part=battery
        cell=four
        metric=68%
        title=Battery

        """),
        Example(name: "browse", text: """
        layout=browse

        part=items
        cell=list
        item=address:Address
        item=signature:Signature
        item=link:Meeting link
        value=address

        part=preview
        cell=preview
        text=Rosenthaler Str. 40\\n10178 Berlin
        readonly=true

        part=copy
        cell=action
        align=right
        look=chip
        title=Copy
        press=true

        part=paste
        cell=bottom
        look=strong
        title=Paste
        press=true
        key=cmd+return

        """),
        Example(name: "a drawing with a floating button", text: """
        grid=t t t t
        grid=t t t t
        grid=t t t c

        part=note
        cell=t
        text=Buy milk\\nCall the bank
        fill=true

        part=save
        cell=c
        look=strong
        press=checkmark
        key=cmd+return
        close=true

        """),
        Example(name: "a drawing of settings", text: """
        grid=a a a a
        grid=b b b b
        grid=s s s s
        grid=e e e e
        grid=l m h r
        grid=- - - -
        grid=q q q q

        part=heating
        cell=a
        look=section
        title=Heating
        on=true

        part=room
        cell=b
        title=Room
        detail=21°

        part=target
        cell=s
        title=Target
        level=40

        part=colors
        cell=e
        color=#e8c07d
        color=#e8edf7
        color=#d4524a
        color=#6fbf6a
        value=#d4524a

        part=low
        cell=l
        title=Low
        color=#5fe0d2

        part=mid
        cell=m
        title=Mid
        color=#5a64e6

        part=high
        cell=h
        title=High
        color=#d632d8

        part=reset
        cell=r
        align=right
        look=bare
        press=arrow.counterclockwise

        part=quit
        cell=q
        look=bare
        title=Quit
        press=true
        key=cmd+q

        """),
        Example(name: "a drawing with keys", text: """
        grid=v v v v
        keys=7 8 9 ÷
        keys=4 5 6 ×
        keys=1 2 3 −
        keys=0 0 . +
        keys=C C C =

        part=value
        cell=v
        metric=1,284
        look=bare

        """)
    ]
}
