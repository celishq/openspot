import Foundation

/// A working sheet for each kind of drawing, for a person to start from in the sandbox and a model to read in the catalog.
public enum SheetExamples {
    public struct Example: Equatable, Sendable {
        public let name: String
        public let text: String
    }

    public static let all: [Example] = [
        Example(name: "text in, text out", text: """
        grid=s s . .
        grid=i i i i
        grid=i i i x
        grid=- - - x
        grid=t t . x
        grid=o o o o
        grid=o o o c
        card=s i t o

        part=source
        cell=s
        option=auto:Automatic
        option=en:English
        value=auto

        part=input
        cell=i
        text=Good morning
        placeholder=Type or paste text

        part=target
        cell=t
        option=fr:French
        option=de:German
        value=fr

        part=output
        cell=o
        text=Bonjour
        readonly=true

        part=swap
        cell=x
        press=arrow.up.arrow.down
        key=cmd+shift+s

        part=copy
        cell=c
        align=right
        look=chip
        title=Copy
        press=true
        key=cmd+return
        close=true

        """),
        Example(name: "a picture with actions", text: """
        grid=a a a a
        grid=a a a a
        grid=a a a a
        grid=a a p p
        grid=a a p p
        grid=t t t t
        grid=s s s s
        grid=. b n .

        part=art
        cell=a
        image=/System/Library/Desktop Pictures/.thumbnails/Sequoia.heic

        part=play
        cell=p
        look=strong
        press=pause.fill

        part=song
        cell=t
        title=Night drive
        detail=2:14 / 3:40

        part=position
        cell=s
        level=60

        part=previous
        cell=b
        look=bare
        press=backward.fill

        part=following
        cell=n
        look=bare
        press=forward.fill

        """),
        Example(name: "a long task", text: """
        grid=f f f f
        grid=q q r r
        grid=p p p p
        grid=p p p p
        grid=l l l l
        grid=l l l c
        card=f q r

        part=file
        cell=f
        title=Demo.mov
        detail=1.2 GB

        part=quality
        cell=q
        option=high:High quality
        option=low:Low quality
        value=high

        part=format
        cell=r
        align=right
        option=mp4:MP4
        value=mp4

        part=status
        cell=p
        block=progress
        title=Converting
        detail=1:12 left
        level=62

        part=log
        cell=l
        text=frame= 4120 fps= 96\\nframe= 4216 fps= 97
        readonly=true

        part=stop
        cell=c
        align=right
        look=chip
        title=Stop
        press=true

        """),
        Example(name: "messages and a field", text: """
        grid=m m m m
        grid=i i i i
        grid=i i i i
        grid=a i i s

        part=messages
        cell=m
        text=Why do the checks fail?\\n\\nThe build step cannot find the module.
        readonly=true

        part=question
        cell=i
        text=
        placeholder=Ask

        part=model
        cell=a
        align=left
        option=fast:Fast
        option=deep:Deep
        value=fast

        part=ask
        cell=s
        look=strong
        press=arrow.up
        key=cmd+return

        """),
        Example(name: "numbers around a chart", text: """
        grid=a a b b
        grid=a a b b
        grid=g g g r
        grid=g g g g
        grid=g g g g
        grid=c c d d
        grid=c c d d

        part=cpu
        cell=a
        metric=42%
        title=CPU

        part=memory
        cell=b
        metric=61%
        title=Memory

        part=history
        cell=g
        point=2
        point=4
        point=3
        point=6
        point=8
        point=5

        part=refresh
        cell=r
        press=arrow.clockwise

        part=disk
        cell=c
        metric=312 GB
        title=Disk free

        part=battery
        cell=d
        metric=68%
        title=Battery

        """),
        Example(name: "a list and a preview", text: """
        grid=l l d d
        grid=l l d d
        grid=l l d c
        grid=b b b b

        part=items
        cell=l
        item=address:Address
        item=signature:Signature
        item=link:Meeting link
        value=address

        part=preview
        cell=d
        text=Rosenthaler Str. 40\\n10178 Berlin
        readonly=true

        part=copy
        cell=c
        align=right
        look=chip
        title=Copy
        press=true

        part=paste
        cell=b
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
