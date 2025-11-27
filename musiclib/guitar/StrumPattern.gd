extends Reference
class_name StrumPattern

"""
Represents a 16-step strumming pattern with its own timing and configuration.

Pattern symbols:
  Strums:
	D = Down fort (strong downstroke)
	d = Down léger (light downstroke)
	U = Up fort (strong upstroke)
	u = Up léger (light upstroke)

  Mutes:
	X = Muté fort (strong muted strum)
	x = Muté léger (light muted strum, shorter and softer)
	W = Double mute fort (two fast muted strums: down+up, strong)
	w = Double mute léger (two fast muted strums: down+up, light)

  Flams:
	F = Flam DU (rapid Down-Up, strong, legato)
	f = Flam du (rapid down-up, light, legato)

  Bass & Arpeggios:
	B = Basse principale (main bass note - lowest)
	b = Basse alternative (alternative bass note)
	0, 1, 2, 3, 4 = Arpeggio notes (0=lowest, 4=highest)

  Other:
	. = Laisser sonner (let ring / sustain)
	' ' = Silence (space = rest)

Usage:
	var pattern = StrumPattern.new()
	pattern.pattern = "D.uDudu D.uDudu "
	pattern.step_beat_length = 0.25  # 16th notes
	pattern.config_override = {"velocity_down_base": 110, "swing_amount": 0.3}

Examples:
	"D.uDudu D.uDudu "  # Classic folk strum
	"B...b...B...b..."  # Alternating bass (country/folk)
	"0.1.2.3.4.3.2.1."  # Ascending/descending arpeggio
	"D.uWu.d.X.uWu.d."  # Rhythmic with double mutes
"""




# The 16-character pattern string
var pattern: String = "D...u...D...u..." setget set_pattern

# Duration of each step in beats
var step_beat_length: float = 0.5

# Dictionary to override FolkGuitarPlayer.config during this pattern
# Example: {"velocity_down_base": 110, "pick_position": 0.5}
var config_override = {
	
	"strum_duration_min": 0.05,  # Durée minimale de balayette (en beats)
	"strum_duration_max": 0.1,  # Durée maximale de balayette (en beats)
	"velocity_curve_shape": "gaussian",  # gaussian, linear, flat
	"velocity_randomization": 0.05,  # Facteur de randomisation (0-1)
	"accent_downbeat_factor": 1.3,  # Multiplication vélocité temps forts
	"mute_duration": 0.02,  # Durée des notes mutées (en beats)
	"humanize_timing": true,  # Micro-décalages temporels
	"timing_variance": 0.005,  # Variance temporelle (en beats)
	"velocity_down_base": 100,  # Vélocité de base pour Down fort
	"velocity_down_light": 50,  # Vélocité de base pour down léger
	"velocity_up_base": 90,  # Vélocité de base pour Up fort
	"velocity_up_light": 40,  # Vélocité de base pour up léger
	"note_overlap": 0.02,  # Léger overlap pour éviter les trous (en beats)
	"pick_position": 0.75,  # Position du médiateur: -1.0 (graves) à 1.0 (aiguës), 0.0 = neutre
	"pick_position_influence": .9,  # Intensité de l'effet (0.0 = aucun, 1.0 = maximum)
	"swing_amount": 0.2,  # Swing: 0.0 = binaire pur, 1.0 = ternaire, entre = intermédiaire
	"chord_transition_gap": 0.95,  # Facteur de raccourcissement des notes avant transition (0.8 = 80%)
	"single_note_velocity": 90,  # Vélocité pour les notes simples (basses, arpèges)
	"max_chords_strings": 4  # Nombre de cordes max pour accords/mutes (1-6), filtre les graves
}

func clone()->StrumPattern:
	var s:StrumPattern = get_script().new()
	s.pattern = pattern
	s.step_beat_length = step_beat_length
	s.config_override = config_override.duplicate(true)
	return s

func set_pattern(value: String) -> void:
	if value.length() != 16:
		push_warning("StrumPattern: Pattern must be exactly 16 characters, got %d. Padding/truncating." % value.length())
		if value.length() < 16:
			value = value + " ".repeat(16 - value.length())
		else:
			value = value.substr(0, 16)
	pattern = value


func get_duration() -> float:
	"""Returns the total duration of this pattern in beats."""
	return 16.0 * step_beat_length


