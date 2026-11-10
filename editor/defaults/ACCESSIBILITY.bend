# ACCESSIBILITY: the editor's accessibility settings. Above everything else.
# Every part of the editor reads these before it moves, flashes or animates.
# Each setting is one line: change its value here.
#
# The person's own system settings count too: an OS "Reduce motion" turns on
# reduce_motion even when it is False here.

import Base

# Motion sickness. True: the camera never travels between views; it cuts
# straight to the new one. The same for any motion added later.
def reduce_motion() -> Bool: True{}
