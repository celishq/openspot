# The look of the panel

These are the decisions about how the panel looks. Each colour, strength and blur radius is in `Surface/SpotTheme.swift`.

| Decision | Why | Rejected |
|---|---|---|
| One progressive backdrop blur close to the cards, and a light dark tint that fades across a 90 pt margin, sampled at full scale, with no constant redraw | One layer gives a soft edge with no line and no second pass, and the long fade of the tint shows no shape, as Control Center does. The system's sampling scale keeps text low-resolution where the mask is zero. | Three masked blur steps, which show a line at the window edge at the system's scale. A system material and Liquid Glass, which do not give this look. |
| The panel follows the Mac's appearance. Light mode has near-white bubbles with a hairline edge and a soft shadow, dark text and a dark turned-on card. Dark mode keeps its see-through look | Dark text on a strong white fill reads on any backdrop. A dark turned-on card stays apart from the selection ring in the accent colour. | A look that reacts to what lies behind the panel, which flips as windows move. An accent turned-on card, which hides the ring. |
| A hidden card keeps its full strength, and Edit Spots marks it with `eye.slash` | The mark says "hidden from the grid", which only that mode shows. A dim card looks disabled, and it is not. | Dimming the card at 40%. A card with no fill, which is weak on a light backdrop. |
| A DMG window that shows where to drag, with no background image | The app and Applications side by side say all that a person needs. | An image with an arrow, which needs upkeep. |
