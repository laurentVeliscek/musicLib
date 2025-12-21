
**MusicLib** is a Godot 3.6 library designed to manipulate chord progressions following classical harmony principles: *keys, scale degrees, harmonic functions, Neapolitan sixth, augmented sixth chords, secondary dominants,* and more.

The central object of MusicLib is the **`Degree`** object.

---

## Creating a Degree

```gdscript
var d:Degree = Degree.new()
```

By default, a Degree is:

* degree **I**
* in **C major**
* a *triad* built on the tonic

---

## Assigning a Key to a Degree

```gdscript
d.key = hk
```

Where **`hk`** is a `HarmonicKey` object (`HarmonicKey.gd`).

A *HarmonicKey* is defined by:

### • `root_midi : int`

The MIDI pitch of the key’s root.

For example, to instantiate A minor, `root_midi` can be **67** or **7**
(the library uses modulo-12 internally: C = 0, C# = 1 … B = 11).

### • `scale_name : string`

The mode of the key.

In tonal harmony, the base modes are:
`major`, `minor`, `harmonic_minor`, `melodic_minor`.

Keys may also be modal or exotic; each mode contains 7 notes, and therefore 7 degrees.

**List of available modes:**

```
[ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian, major, minor, harmonic_minor, locrian_n6, ionian_#5, ukrainian_dorian, phrygian_dominant, lydian_#2, ultralocrian, melodic_minor, dorian_b2, lydian_#5, overtone, hindu, half_diminished, altered, harmonic_major, gypsy_major, hungarian_major, gypsy_minor, neapolitan_major, neapolitan_minor, enigmatic, persian, major_locrian, leading_whole_tone, romanian_major, augmented_heptatonic]
```

### Instantiating a HarmonicKey

```gdscript
var myKey:HarmonicKey = HarmonicKey.new()
myKey.root = 2              # D
myKey.scale_name = "harmonic_minor"
```

Assigning it to our Degree:

```gdscript
d.key = myKey
```

---

## Degree Number

```gdscript
d.degree_number = 1..7
```

In classical harmony, the tonic is **degree 1**, not 0.

Each object has a `to_string() -> string` function for easy display.

---

## Logging

MusicLib uses a **LogBus** object for tracing and debugging.

Each object defines:

```gdscript
const TAG = "object_name"
LogBus.debug(TAG, d.to_string())
```

Example output:

```
Degree: ii° of key: D harmonic_minor(62), Duration: 4 beats, harmonic function: PD
kind: diatonic, realization: [1, 3, 5], inversion: 0
Roman Numeral: ii°, jazz chord: Edim, midi: [64, 67, 70] -> [E4, G4, A#4]
```

---

## Other Degree Properties

### • Duration (in beats)

```gdscript
d.length_beats = 4       # whole note
```

### • Realization

The chord tones to include:

```gdscript
d.realization = [1, 3, 5, 7]   # a seventh chord
```

### • Inversion

```gdscript
d.inversion = 1               # first inversion (third in the bass)
```

### • Harmonic Function

T = Tonic • PD = Predominant • D = Dominant

```gdscript
d.set_harmonic_function("PD")
```

### • Kind (chord type)

Default: **"diatonic"**

It can also be:

* Neapolitan sixth: `N6`
* augmented sixth chords: `It+6`, `Fr+6`, `Ger+6`
* cadential 6/4: `cad64`
* suspended: `sus2`, `sus4`
* added tones: `add9`, `add11`
* melodic (single-note degree)

Setter examples:

```gdscript
d.set_N6()
d.set_aug6_It()
```

Notice that secondary dominants are not a special kind and are set as diatonic chords in their key

**List of recognized kinds:**

```
["melodic","diatonic",
 "It+6","Fr+6","Ger+6","It+6inv","Fr+6inv","Ger+6inv",
 "N6","chrom.","cad64","sus2","sus4","add9","add11"]
```

*(“chrom.” is not yet implemented.)*


There's a special kind of Degree : "melodic"

This Degree is to be used for "monophonic" melodic Degrees.
You can set the melody note referenced to the current chord, has a degree of this chord

Example: the melody note is the third of the IV Degree in key F major

```
	var hk:HarmonicKey = HarmonicKey.new()
	hk.scale_name = "major" # major key
	hk.root = 5				# root if F
	var d:Degree = Degree.new()
	d.key = hk
	d.degree_number= 4		# = Bb
	print(d.to_string())
	d.set_melodic()
	d.realization = [3]		# -> D
		
	print(d.to_string())
	#Degree: IV of key: F major (4), Duration: 4 beats, harmonic function: PD
	#kind: melodic, realization: [3], inversion: 0
	#Roman Numeral: ?, jazz chord: ?, midi: [74] -> [D5]

```


---

## Altering the Degree

```gdscript
func set_key_alteration(degree:int, alter:alter)
```

Example:
Alter the 6th degree of *harmonic_minor* to obtain *melodic_minor*:

```gdscript
d.set_key_alteration(6, 1)
```

Alterations are stored in:

```gdscript
d._alterations = {6: 1}
```

A free text comment can be added:

```gdscript
d.comment = "secondary dominant"
```

A free Dictionary _comment (with an underscore !) can be set:

```gdscript
	d._comment["is_secondary"]= true
	d._comment["secondary_target_degree"]= 5
```

---

## Tracks

Degrees can be placed into a **Track**:

```gdscript
var tr:Track = Track.new()
tr.add_degree(2, d)   # place on beat 3 (time 0 = beat 1)
```

Velocity:

```gdscript
d.velocity = 90
```

---

## Song Object

A **Song** aggregates tracks:

```gdscript
var mySong:Song = Song.new()
```

### Time signature

```gdscript
mySong.time_num = 3
mySong.time_den = 4       # waltz
```

### Tempo

```gdscript
mySong.tempo_bpm = 140
```

### MIDI-oriented objects

Located in *musicLib/Core*:
`Note`, `ProgramChange`, `MidiCC`

---

## Guitar Chords and Visualization

MusicLib allows:

* associating guitar chord shapes with any Degree
* displaying them
* visualizing Tracks using different representations:

  * Roman numeral notation
  * MIDI notes
  * jazz chord symbols
  * keyboard layout
    (using `songTrackView`)




