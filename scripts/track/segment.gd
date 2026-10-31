class_name Segment
extends RefCounted
## One short slice of road. The renderer projects both ends every frame.

const FLAG_START := 1
const FLAG_CHECKPOINT := 2
const FLAG_FINISH := 4

var index := 0
var w1 := Vector3.ZERO  # world point at the near end (y = height, z = distance)
var w2 := Vector3.ZERO  # world point at the far end
var curve := 0.0
var band := 0  # alternating color band for stripes
var ground_left := 0
var ground_right := 0
var flags := 0
var sprites: Array = []  # [{"id": String, "offset": float, "flip": bool}]
var cars: Array = []  # traffic cars currently in this segment
var spans: Array[String] = []  # road-spanning sprite ids (SpriteLibrary.spans) at the near end
var covered := false  # inside a tunnel or covered bridge: darker, no sky

# Projection results, rewritten every frame by the renderer
var cam_z1 := 0.0
var cam_z2 := 0.0
var scale1 := 0.0
var scale2 := 0.0
var s1 := Vector2.ZERO
var s2 := Vector2.ZERO
var sw1 := 0.0
var sw2 := 0.0
var clip := 0.0  # top of the road already covered by nearer segments
var fog := 0.0
var visible := false
