class_name FarmLayout
extends RefCounted
## Deterministic layout of the farm greybox (ANA-GAME-002-A). Pure data + math, no nodes.
## The terrain mesh, its collision and the tests all derive from `height_at()`, so visuals,
## physics and tests can never disagree. Coordinates: +Y up, -Z is "north", 1 unit = 1 m.
## World is centered on the origin and spans [-HALF_SIZE, +HALF_SIZE] on X and Z.

const HALF_SIZE := 80.0
const CELL_SIZE := 1.0
const GRID_VERTICES := int(HALF_SIZE * 2.0 / CELL_SIZE) + 1  # 161 per side

# Outer rim: terrain rises smoothly near the edge so the map is naturally enclosed.
# (Invisible walls at the very edge are the hard stop.)
const RIM_START := 72.0
const RIM_HEIGHT := 4.0

# --- Zone A: starting area (flat) -------------------------------------------------------------
const SPAWN := Vector2(0.0, 0.0)
const VEHICLE_PARKING := Vector2(4.0, -4.0)

# --- Zone B: gentle hills (gaussian bumps). x = center X, y = center Z, z = height (m), w = sigma (m) ------------
const HILLS: Array[Vector4] = [
	Vector4(-50.0, -8.0, 3.0, 12.0),
	Vector4(-58.0, -32.0, 4.0, 12.0),
	Vector4(-24.0, -40.0, 2.5, 11.0),
	Vector4(-66.0, 14.0, 2.8, 11.0),
	Vector4(30.0, 40.0, 2.8, 11.0),
	Vector4(-22.0, 28.0, 2.2, 11.0),
]

# --- Zone C: dirt paths (polylines, x/z). Rounded joints give smooth intersections -------------
const PATH_WIDTH := 5.0
const PATHS: Array = [
	# North to the barn reserve
	[Vector2(0, 0), Vector2(0, -18), Vector2(-3, -36), Vector2(0, -48), Vector2(0, -56)],
	# East to the ramp plaza
	[Vector2(0, 0), Vector2(14, 0), Vector2(30, 0), Vector2(48, 0), Vector2(68, 0)],
	# West over the hills (ends on the highest hilltop)
	[Vector2(0, 0), Vector2(-14, 3), Vector2(-30, -4), Vector2(-46, -14), Vector2(-56, -30)],
	# South hub and its two branches
	[Vector2(0, 0), Vector2(0, 20), Vector2(2, 40), Vector2(0, 52)],
	[Vector2(0, 52), Vector2(-24, 50), Vector2(-46, 46)],
	[Vector2(0, 52), Vector2(26, 52), Vector2(50, 50)],
	# North-east loop: barn -> plaza, with a spur to the expansion reserve
	[Vector2(0, -48), Vector2(22, -44), Vector2(46, -34), Vector2(60, -18), Vector2(66, -6), Vector2(68, 0)],
	[Vector2(46, -34), Vector2(62, -45)],
]

# --- Zone D: ramp test plaza (flat). Ramps face +X; run-up comes from the path along z=0 -------
const PLAZA_CENTER := Vector2(48.0, 0.0)
const PLAZA_HALF := Vector2(22.0, 18.0)
const PLAZA_BLEND := 8.0
const RAMP_SMALL_POS := Vector2(40.0, -9.0)   # 3 m wide, 4 m long, 0.5 m rise
const RAMP_MEDIUM_POS := Vector2(40.0, 0.0)   # 4 m wide, 8 m long, 1.5 m rise
const MOUND := Vector4(47.0, 15.0, 2.0, 10.0)  # naturally inclined dome: cx, cz, height, radius (compact support)

# --- Zone E: future barn reserve (flat) -------------------------------------------------------
const BARN_RESERVE := Vector2(0.0, -62.0)

# --- Zone F: future expansion reserves (flat) -------------------------------------------------
const RESERVE_KITTENS := Vector2(-46.0, 46.0)
const RESERVE_LANDMARK := Vector2(50.0, 50.0)
const RESERVE_EXPANSION := Vector2(62.0, -45.0)

# Flat plateaus as discs: x = center X, y = center Z, z = fully-flat radius, w = blend-out radius.
# Hills fade out over the blend ring, so blends are long enough to keep every slope gentle.
const FLAT_DISCS: Array[Vector4] = [
	Vector4(0.0, 0.0, 16.0, 46.0),     # start area (long blend keeps nearby hills gentle)
	Vector4(0.0, -56.0, 14.0, 34.0),   # barn reserve plateau
	Vector4(-46.0, 46.0, 9.0, 30.0),
	Vector4(50.0, 50.0, 9.0, 30.0),
	Vector4(62.0, -45.0, 9.0, 30.0),
	Vector4(0.0, 52.0, 9.0, 28.0),     # south hub
]

# Colored pads on the ground: x = center X, y = center Z, z = half-width X, w = half-depth Z.
const PADS: Array[Vector4] = [
	Vector4(4.0, -4.0, 2.5, 1.8),       # vehicle parking
	Vector4(0.0, -62.0, 9.0, 7.0),      # barn
	Vector4(-46.0, 46.0, 6.0, 6.0),
	Vector4(50.0, 50.0, 6.0, 6.0),
	Vector4(62.0, -45.0, 6.0, 6.0),
	Vector4(52.0, 0.0, 8.0, 5.0),       # landing area of the medium ramp
]

# Per-ramp dimensions: length (along travel), width, rise.
const RAMP_SMALL := Vector3(4.0, 3.0, 0.5)
const RAMP_MEDIUM := Vector3(8.0, 4.0, 1.5)


## Terrain height (m) at world position (x, z).
static func height_at(x: float, z: float) -> float:
	var flat := _flatten_weight(x, z)
	var h := 0.0
	for hill in HILLS:
		var dx := x - hill.x
		var dz := z - hill.y
		h += hill.z * exp(-(dx * dx + dz * dz) / (2.0 * hill.w * hill.w))
	# Small deterministic undulation so open grass is not dead flat.
	h += 0.2 * sin(x * 0.09 + 1.0) * cos(z * 0.08)
	h *= (1.0 - flat)
	# Mound lives inside the flat plaza, so it is added after flattening.
	h += MOUND.z * (1.0 - smoothstep(0.0, MOUND.w, Vector2(x - MOUND.x, z - MOUND.y).length()))
	# Rim.
	var edge := maxf(absf(x), absf(z))
	var t := clampf((edge - RIM_START) / (HALF_SIZE - RIM_START), 0.0, 1.0)
	h += RIM_HEIGHT * smoothstep(0.0, 1.0, t)
	return h


## 0..1, 1 on the dirt path center, softly fading over ~1 m at the edge.
static func path_mask_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for path in PATHS:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var ab: Vector2 = path[i + 1] - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_squared_to(a + ab * u))
	var half := PATH_WIDTH * 0.5
	return 1.0 - smoothstep(half - 0.5, half + 0.5, sqrt(best))


## 0..1 for the colored reserve/parking/landing pads.
static func pad_mask_at(x: float, z: float) -> float:
	var m := 0.0
	for pad in PADS:
		var ex := absf(x - pad.x) - pad.z
		var ez := absf(z - pad.y) - pad.w
		var d := maxf(ex, ez)
		m = maxf(m, 1.0 - smoothstep(-0.5, 0.5, d))
	return m


## Terrain surface normal from the analytic height field.
static func normal_at(x: float, z: float) -> Vector3:
	var e := CELL_SIZE * 0.5
	var dhdx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dhdz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


## Zone letter ("A".."F") for a world position, or "" for open farmland.
static func zone_at(x: float, z: float) -> String:
	if _in_rect(x, z, PLAZA_CENTER, PLAZA_HALF):
		return "D"
	if _in_rect(x, z, BARN_RESERVE, Vector2(9.0, 7.0)):
		return "E"
	for r in [RESERVE_KITTENS, RESERVE_LANDMARK, RESERVE_EXPANSION]:
		if _in_rect(x, z, r, Vector2(6.0, 6.0)):
			return "F"
	if Vector2(x, z).distance_to(SPAWN) <= 16.0:
		return "A"
	if path_mask_at(x, z) > 0.5:
		return "C"
	for hill in HILLS:
		if Vector2(x - hill.x, z - hill.y).length() < hill.w * 1.5:
			return "B"
	return ""


static func _in_rect(x: float, z: float, center: Vector2, half: Vector2) -> bool:
	return absf(x - center.x) <= half.x and absf(z - center.y) <= half.y


## 1 on flat plateaus, 0 on open farmland.
static func _flatten_weight(x: float, z: float) -> float:
	var w := 0.0
	for d in FLAT_DISCS:
		var dist := Vector2(x - d.x, z - d.y).length()
		w = maxf(w, 1.0 - smoothstep(d.z, d.w, dist))
	var dx := maxf(absf(x - PLAZA_CENTER.x) - PLAZA_HALF.x, 0.0)
	var dz := maxf(absf(z - PLAZA_CENTER.y) - PLAZA_HALF.y, 0.0)
	w = maxf(w, 1.0 - smoothstep(0.0, PLAZA_BLEND, sqrt(dx * dx + dz * dz)))
	return w
