import Foundation

/// A working sheet for each kind of drawing, for a person to start from in the sandbox and a model to read in the catalog.
public enum SheetExamples {
    public struct Example: Equatable, Sendable {
        public let name: String
        public let text: String
    }

    public static let all: [Example] = [
        Example(name: "text in, text out", text: """
        grid=source source . .
        grid=input input input input
        grid=input input input swap
        grid=- - - swap
        grid=target target . swap
        grid=output output output output
        grid=output output output copy

        choice=source
        option=auto:Automatic
        option=en:English
        value=auto

        field=input
        value=Good morning
        placeholder=Type or paste text

        choice=target
        option=fr:French
        option=de:German
        value=fr

        field=output
        value=Bonjour
        readonly=true

        button=swap
        icon=arrow.up.arrow.down
        shortcut=cmd+shift+s

        button=copy
        align=right
        look=chip
        title=Copy
        shortcut=cmd+return
        close=true

        """),
        Example(name: "a picture with actions", text: """
        grid=art art art art
        grid=art art art art
        grid=art art art art
        grid=art art play play
        grid=art art play play
        grid=song song song song
        grid=position position position position
        grid=. previous following .

        picture=art
        icon=/System/Library/Desktop Pictures/.thumbnails/Sequoia.heic

        button=play
        look=strong
        icon=pause.fill

        text=song
        title=Night drive
        detail=2:14 / 3:40

        slider=position
        value=60

        button=previous
        look=bare
        icon=backward.fill

        button=following
        look=bare
        icon=forward.fill

        """),
        Example(name: "a long task", text: """
        grid=file file file file
        grid=quality quality format format
        grid=status status status status
        grid=status status status status
        grid=log log log log
        grid=log log log stop

        text=file
        title=Demo.mov
        detail=1.2 GB

        choice=quality
        option=high:High quality
        option=low:Low quality
        value=high

        choice=format
        align=right
        option=mp4:MP4
        value=mp4

        gauge=status
        title=Converting
        detail=1:12 left
        value=0.62

        field=log
        value=frame= 4120 fps= 96\\nframe= 4216 fps= 97
        readonly=true

        button=stop
        align=right
        look=chip
        title=Stop

        """),
        Example(name: "messages and a field", text: """
        grid=messages messages messages messages
        grid=question question question question
        grid=question question question question
        grid=model question question ask

        field=messages
        value=Why do the checks fail?\\n\\nThe build step cannot find the module.
        readonly=true

        field=question
        value=
        placeholder=Ask

        choice=model
        align=left
        option=fast:Fast
        option=deep:Deep
        value=fast

        button=ask
        look=strong
        icon=arrow.up
        shortcut=cmd+return

        """),
        Example(name: "numbers around a chart", text: """
        grid=cpu cpu memory memory
        grid=cpu cpu memory memory
        grid=history history history refresh
        grid=history history history history
        grid=history history history history
        grid=disk disk battery battery
        grid=disk disk battery battery

        number=cpu
        value=42%
        title=CPU

        number=memory
        value=61%
        title=Memory

        graph=history
        value=2
        value=4
        value=3
        value=6
        value=8
        value=5

        button=refresh
        icon=arrow.clockwise

        number=disk
        value=312 GB
        title=Disk free

        number=battery
        value=68%
        title=Battery

        """),
        Example(name: "a list and a preview", text: """
        grid=items items preview preview
        grid=items items preview preview
        grid=items items preview copy
        grid=paste paste paste paste

        choice=items
        option=address:Address
        option=signature:Signature
        option=link:Meeting link
        value=address

        field=preview
        value=Rosenthaler Str. 40\\n10178 Berlin
        readonly=true

        button=copy
        align=right
        look=chip
        title=Copy

        button=paste
        look=strong
        title=Paste
        shortcut=cmd+return

        """),
        Example(name: "a drawing with a floating button", text: """
        grid=note note note note
        grid=note note note note
        grid=note note note save

        field=note
        value=Buy milk\\nCall the bank

        button=save
        look=strong
        icon=checkmark
        shortcut=cmd+return
        close=true

        """),
        Example(name: "a drawing of settings", text: """
        grid=heating heating heating heating
        grid=room room room room
        grid=target target target target
        grid=colors colors colors colors
        grid=low mid high reset
        grid=- - - -
        grid=quit quit quit quit

        switch=heating
        title=Heating
        value=true

        text=room
        title=Room
        detail=21°

        slider=target
        title=Target
        value=40

        choice=colors
        color=#e8c07d
        color=#e8edf7
        color=#d4524a
        color=#6fbf6a
        value=#d4524a

        choice=low
        title=Low
        color=#5fe0d2

        choice=mid
        title=Mid
        color=#5a64e6

        choice=high
        title=High
        color=#d632d8

        button=reset
        align=right
        look=bare
        icon=arrow.counterclockwise

        button=quit
        look=bare
        title=Quit
        shortcut=cmd+q

        """),
        tiles
    ]

    /// A grid of emoji under a choice, whose rows fill a repeated area of the drawing.
    public static let tiles = Example(name: "a grid of emoji", text: """
    grid=tone tone tone tone tone tone tone
    grid=a a a a a a a

    repeat=a
    grid=a b c d e f g

    button=open
    title=Copy

    choice=tone
    title=Skin tone
    option=none:Yellow
    option=light:Light
    value=none

    row=grin
    title=Grinning face
    icon=😀

    row=joy
    title=Tears of joy
    icon=😂

    row=love
    title=Heart eyes
    icon=😍

    row=think
    title=Thinking face
    icon=🤔

    row=party
    title=Party face
    icon=🥳

    row=cool
    title=Sunglasses
    icon=😎

    row=wave
    title=Waving hand
    icon=👋

    row=dog
    title=Dog face
    icon=🐶

    row=fox
    title=Fox
    icon=🦊

    row=flower
    title=Cherry blossom
    icon=🌸

    row=fire
    title=Fire
    icon=🔥

    row=pizza
    title=Pizza
    icon=🍕

    row=rocket
    title=Rocket
    icon=🚀

    row=heart
    title=Red heart
    icon=❤️

    """)
}
