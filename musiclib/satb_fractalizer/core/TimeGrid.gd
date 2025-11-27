extends Node

const TAG = "TimeGrid"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var time_num           # int (4 for 4/4)
var time_den           # int (4 for 4/4)
var grid_unit          # float (0.25 for double eighth note)
var beat_strength_map  # Dictionary {beat_position: "strong"/"medium"/"weak"}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(num, den, unit):
	time_num = num
	time_den = den
	grid_unit = unit
	beat_strength_map = _build_beat_strength_map()

	LogBus.debug(TAG, "Created TimeGrid: " + str(time_num) + "/" + str(time_den) + " grid_unit=" + str(grid_unit))

# =============================================================================
# BUILD BEAT STRENGTH MAP
# =============================================================================

func _build_beat_strength_map():
	var strength_map = {}

	# Pattern depends on time signature
	if time_num == 4:
		# 4/4: beat 0=strong, 1=weak, 2=medium, 3=weak
		strength_map[0.0] = Constants.BEAT_STRONG
		strength_map[1.0] = Constants.BEAT_WEAK
		strength_map[2.0] = Constants.BEAT_MEDIUM
		strength_map[3.0] = Constants.BEAT_WEAK

		# Subdivisions are weak
		for i in range(4):
			strength_map[i + 0.25] = Constants.BEAT_WEAK
			strength_map[i + 0.5] = Constants.BEAT_WEAK
			strength_map[i + 0.75] = Constants.BEAT_WEAK

	elif time_num == 3:
		# 3/4: beat 0=strong, 1=weak, 2=weak
		strength_map[0.0] = Constants.BEAT_STRONG
		strength_map[1.0] = Constants.BEAT_WEAK
		strength_map[2.0] = Constants.BEAT_WEAK

		# Subdivisions are weak
		for i in range(3):
			strength_map[i + 0.25] = Constants.BEAT_WEAK
			strength_map[i + 0.5] = Constants.BEAT_WEAK
			strength_map[i + 0.75] = Constants.BEAT_WEAK

	elif time_num == 5:
		# 5/4: beat 0=strong, 1=weak, 2=weak, 3=medium, 4=weak
		strength_map[0.0] = Constants.BEAT_STRONG
		strength_map[1.0] = Constants.BEAT_WEAK
		strength_map[2.0] = Constants.BEAT_WEAK
		strength_map[3.0] = Constants.BEAT_MEDIUM
		strength_map[4.0] = Constants.BEAT_WEAK

		# Subdivisions are weak
		for i in range(5):
			strength_map[i + 0.25] = Constants.BEAT_WEAK
			strength_map[i + 0.5] = Constants.BEAT_WEAK
			strength_map[i + 0.75] = Constants.BEAT_WEAK

	elif time_num == 7:
		# 7/4: beat 0=strong, 1=weak, 2=weak, 3=medium, 4=weak, 5=medium, 6=weak
		strength_map[0.0] = Constants.BEAT_STRONG
		strength_map[1.0] = Constants.BEAT_WEAK
		strength_map[2.0] = Constants.BEAT_WEAK
		strength_map[3.0] = Constants.BEAT_MEDIUM
		strength_map[4.0] = Constants.BEAT_WEAK
		strength_map[5.0] = Constants.BEAT_MEDIUM
		strength_map[6.0] = Constants.BEAT_WEAK

		# Subdivisions are weak
		for i in range(7):
			strength_map[i + 0.25] = Constants.BEAT_WEAK
			strength_map[i + 0.5] = Constants.BEAT_WEAK
			strength_map[i + 0.75] = Constants.BEAT_WEAK

	else:
		LogBus.warn(TAG, "_build_beat_strength_map: unsupported time signature " + str(time_num) + "/" + str(time_den))
		# Default: first beat strong, rest weak
		strength_map[0.0] = Constants.BEAT_STRONG
		for i in range(1, time_num):
			strength_map[float(i)] = Constants.BEAT_WEAK

	return strength_map

# =============================================================================
# BEAT STRENGTH
# =============================================================================

func get_beat_strength(time_position):
	# Returns "strong", "medium", or "weak"
	# time_position is relative to the start of the measure (bar)

	var position_in_measure = fmod(time_position, float(time_num))

	# Check if position is on a whole beat (0.0, 1.0, 2.0, 3.0, etc.)
	# This handles triplets where the first note is on a beat but subsequent notes are off-grid
	var nearest_beat = round(position_in_measure)
	if abs(position_in_measure - nearest_beat) < 0.01:  # Tolerance for floating point
		if beat_strength_map.has(float(nearest_beat)):
			return beat_strength_map[float(nearest_beat)]

	# Round to nearest grid subdivision to handle binary subdivisions
	var rounded = stepify(position_in_measure, grid_unit)

	if beat_strength_map.has(rounded):
		return beat_strength_map[rounded]
	else:
		# Default to weak for unknown positions (e.g., triplet subdivisions like 0.333, 0.666)
		return Constants.BEAT_WEAK

# =============================================================================
# TIME <-> CELLS CONVERSION
# =============================================================================

func time_to_cells(time):
	return int(round(time / grid_unit))

func cells_to_time(cells):
	return cells * grid_unit

func is_on_grid(time):
	var cells = time / grid_unit
	return abs(cells - round(cells)) < 0.0001

# =============================================================================
# DEBUG
# =============================================================================

func to_string():
	return "TimeGrid(" + str(time_num) + "/" + str(time_den) + ", grid=" + str(grid_unit) + ")"
