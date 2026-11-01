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
var grip := 1.0  # the road's grip (RC-12): 1 dry; lower when wet or snowy (Track.set_grip)
## The road's half-width at the near and far ends, in Cfg.ROAD_WIDTH (1 the usual four lanes),
## and its lane count (WS-7, Track.set_width). Car and pickup x is in Cfg.ROAD_WIDTH too, so a
## car keeps its place across a narrowing; roadside sprite offsets are in this segment's
## half-widths, so props follow the edge.
var width := 1.0
var width_far := 1.0
var lanes := Cfg.LANES
var flags := 0
var sprites: Array = []  # [{"id": String, "offset": float, "flip": bool}]
var cars: Array = []  # traffic cars currently in this segment
var spans: Array[String] = []  # road-spanning sprite ids (SpriteLibrary.spans) at the near end
var covered := false  # inside a tunnel or covered bridge: darker, no sky
var depth := 0.0  # how far into the tunnel, 0 at a mouth to 1 well inside: darker still
var pickups: Array = []  # PowerUps.Pickup lying in this segment
var handover := 0.0  # its share of the next stage's palette (StageFlow.blend), 0 to 1

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
var shade := 0.0  # the share of the next stage's palette it is drawn in this frame


## The half-width `p` (0 near end, 1 far end) along the segment.
func width_at(p: float) -> float:
	return lerpf(width, width_far, p)


## Where across the road lane `k` (0 the leftmost) of this segment's runs, at its near end.
func lane_x(k: int) -> float:
	return width * (-1.0 + (2.0 * k + 1.0) / lanes)


## The middle of every lane, left to right (Traffic.LANE_OFFSETS on the usual road).
func lane_offsets() -> Array[float]:
	var out: Array[float] = []
	for k in lanes:
		out.append(lane_x(k))
	return out


## The middle of the lane `frac` of the way across the road (0 left edge, 1 right edge).
func lane_at(frac: float) -> float:
	return lane_x(clampi(floori(frac * lanes), 0, lanes - 1))
