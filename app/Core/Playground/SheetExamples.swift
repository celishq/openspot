import Foundation

public enum SheetExamples {
    public struct Example: Equatable, Sendable {
        public let name: String
        public let text: String
    }

    public static let all: [Example] = [
        Example(name: "text in, text out", text: """
        frame=
        class=gap-part

        choice=source
        value=auto

        option=auto
        title=Automatic

        option=en
        title=English

        field=input
        class=grow
        type=multiline
        value=Good morning
        placeholder=Type or paste text

        box=middle
        class=flex-row items-center gap-part

        box=line
        parent=middle
        class=grow h-px bg-tile

        button=swap
        parent=middle
        icon=arrow.up.arrow.down
        shortcut=cmd+shift+s

        choice=target
        value=fr

        option=fr
        title=French

        option=de
        title=German

        box=result
        class=relative grow

        field=output
        parent=result
        class=absolute inset-0
        type=multiline
        value=Bonjour
        readonly=true

        box=corner
        parent=result
        class=absolute inset-0 justify-end items-end p-2

        button=copy
        parent=corner
        class=rounded-full
        title=Copy
        shortcut=cmd+return

        """),
        Example(name: "a picture with actions", text: """
        frame=
        class=gap-part

        box=top
        class=grid grid-cols-2 gap-part

        picture=art
        parent=top
        class=h-56
        icon=/System/Library/Desktop Pictures/.thumbnails/Sequoia.heic

        box=side
        parent=top
        class=justify-end

        button=play
        parent=side
        class=h-20 bg-accent
        icon=pause.fill

        text=song
        title=Night drive
        detail=2:14 / 3:40

        field=position
        type=slider
        value=60

        box=controls
        class=flex-row justify-center gap-part

        button=previous
        parent=controls
        class=bg-transparent
        icon=backward.fill

        button=following
        parent=controls
        class=bg-transparent
        icon=forward.fill

        """),
        Example(name: "a long task", text: """
        frame=
        class=gap-part

        text=file
        title=Demo.mov
        detail=1.2 GB

        box=options
        class=flex-row justify-between gap-part

        choice=quality
        parent=options
        value=high

        option=high
        title=High quality

        option=low
        title=Low quality

        choice=format
        parent=options
        value=mp4

        option=mp4
        title=MP4

        number=status
        class=h-20
        title=Converting
        detail=1:12 left
        value=62
        max=100
        unit=%

        box=output
        class=relative grow

        field=log
        parent=output
        class=absolute inset-0
        value=frame= 4120 fps= 96\\nframe= 4216 fps= 97
        readonly=true

        box=corner
        parent=output
        class=absolute inset-0 justify-end items-end p-2

        button=stop
        parent=corner
        class=rounded-full
        title=Stop

        """),
        Example(name: "messages and a field", text: """
        frame=
        class=gap-part

        field=messages
        class=grow
        value=Why do the checks fail?\\n\\nThe build step cannot find the module.
        readonly=true

        field=question
        class=h-20
        value=
        placeholder=Ask

        box=bottom
        class=flex-row items-center justify-between gap-part

        choice=model
        parent=bottom
        value=fast

        option=fast
        title=Fast

        option=deep
        title=Deep

        button=ask
        parent=bottom
        class=bg-accent
        icon=arrow.up
        shortcut=cmd+return

        """),
        Example(name: "numbers around a chart", text: """
        frame=
        class=grid grid-cols-2 gap-part

        number=cpu
        class=h-20
        value=42%
        title=CPU

        number=memory
        class=h-20
        value=61%
        title=Memory

        box=chart
        class=col-span-2 relative h-32

        number=history
        parent=chart
        class=absolute inset-0
        value=2
        value=4
        value=3
        value=6
        value=8
        value=5

        button=refresh
        parent=chart
        class=absolute top-0 right-0
        icon=arrow.clockwise

        number=disk
        class=h-20
        value=312 GB
        title=Disk free

        number=battery
        class=h-20
        value=68%
        title=Battery

        """),
        Example(name: "a list and a preview", text: """
        frame=
        class=gap-part

        box=top
        class=grid grid-cols-2 gap-part

        choice=items
        parent=top
        class=h-32
        value=address

        option=address
        title=Address

        option=signature
        title=Signature

        option=link
        title=Meeting link

        box=side
        parent=top
        class=relative

        field=preview
        parent=side
        class=absolute inset-0
        value=Rosenthaler Str. 40\\n10178 Berlin
        readonly=true

        box=corner
        parent=side
        class=absolute inset-0 justify-end items-end p-2

        button=copy
        parent=corner
        class=rounded-full
        title=Copy

        button=paste
        class=bg-accent
        title=Paste
        shortcut=cmd+return

        """),
        Example(name: "a drawing with a floating button", text: """
        frame=
        class=gap-part

        box=page
        class=relative h-32

        field=note
        parent=page
        class=absolute inset-0
        value=Buy milk\\nCall the bank

        box=corner
        parent=page
        class=absolute inset-0 justify-end items-end p-2

        button=save
        parent=corner
        class=bg-accent
        icon=checkmark
        shortcut=cmd+return

        """),
        Example(name: "a drawing of settings", text: """
        frame=
        class=gap-part

        switch=heating
        title=Heating
        value=true

        text=room
        title=Room
        detail=21°

        field=target
        type=slider
        title=Target
        value=40

        choice=colors
        color=#e8c07d
        color=#e8edf7
        color=#d4524a
        color=#6fbf6a
        value=#d4524a

        box=levels
        class=grid grid-cols-4 gap-part

        choice=low
        parent=levels
        title=Low
        color=#5fe0d2

        choice=mid
        parent=levels
        title=Mid
        color=#5a64e6

        choice=high
        parent=levels
        title=High
        color=#d632d8

        button=reset
        parent=levels
        class=bg-transparent text-right
        icon=arrow.counterclockwise

        box=line
        class=h-px bg-tile

        button=quit
        class=bg-transparent
        title=Quit
        shortcut=cmd+q

        """),
        tiles
    ]

    public static let tiles = Example(name: "a grid of emoji", text: """
    frame=
    class=gap-part

    choice=tone
    title=Skin tone
    value=none

    option=none
    title=Yellow

    option=light
    title=Light

    items=a
    class=grid grid-cols-7

    button=open
    parent=a
    title=Copy

    text=grin
    parent=a
    title=Grinning face
    icon=😀

    text=joy
    parent=a
    title=Tears of joy
    icon=😂

    text=love
    parent=a
    title=Heart eyes
    icon=😍

    text=think
    parent=a
    title=Thinking face
    icon=🤔

    text=party
    parent=a
    title=Party face
    icon=🥳

    text=cool
    parent=a
    title=Sunglasses
    icon=😎

    text=wave
    parent=a
    title=Waving hand
    icon=👋

    text=dog
    parent=a
    title=Dog face
    icon=🐶

    text=fox
    parent=a
    title=Fox
    icon=🦊

    text=flower
    parent=a
    title=Cherry blossom
    icon=🌸

    text=fire
    parent=a
    title=Fire
    icon=🔥

    text=pizza
    parent=a
    title=Pizza
    icon=🍕

    text=rocket
    parent=a
    title=Rocket
    icon=🚀

    text=heart
    parent=a
    title=Red heart
    icon=❤️

    """)
}
