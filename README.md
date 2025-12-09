
musicLib
========

---

# 🇫🇷 Présentation

**MusicLib** est une librairie Godot 3.6 conçue pour manipuler des progressions d’accords en s’appuyant sur les principes de l’harmonie classique : tonalités, degrés, fonctions harmoniques, sixtes napolitaines, accords de sixte augmentée, dominantes secondaires, etc.

L’objet central de MusicLib est l’objet **`Degree`**.

---

# 🇬🇧 Overview

**MusicLib** is a Godot 3.6 library designed to manipulate chord progressions based on classical harmony principles: keys, scale degrees, harmonic functions, Neapolitan sixth, augmented sixth chords, secondary dominants, and more.

The central object of MusicLib is the **`Degree`** object.

---

# 🇫🇷 Création d’un Degree

# 🇬🇧 Creating a Degree

```gdscript
var d:Degree = Degree.new()
```

Par défaut, le degré est le I en Do majeur, sous forme de triade.
By default, the degree is I in C major, as a triad.

---

# 🇫🇷 Tonalité (HarmonicKey)

# 🇬🇧 Key (HarmonicKey)

Pour associer une tonalité :
To assign a key:

```gdscript
d.key = hk
```

Une tonalité est définie par :
A key is defined by:

* **root_midi : int** — hauteur MIDI de la tonique
  *MIDI pitch of the root note*
* **scale_name : string** — le mode de la tonalité
  *the mode of the key*

Modes disponibles :
Available modes:

```
ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian,
major, minor, harmonic_minor, melodic_minor, locrian_n6, ionian_#5,
ukrainian_dorian, phrygian_dominant, lydian_#2, ultralocrian,
dorian_b2, lydian_#5, overtone, hindu, half_diminished, altered,
harmonic_major, double_harmonic, double_harmonic_major, byzantine,
gypsy_major, hungarian_major, hungarian_minor, gypsy_minor,
neapolitan_major, neapolitan_minor, enigmatic, persian,
major_locrian, leading_whole_tone, romanian_major
```

Exemple / Example:

```gdscript
var myKey = HarmonicKey.new()
myKey.root_midi = 2              # D
myKey.scale_name = "harmonic_minor"
d.key = myKey
```

---

# 🇫🇷 Numéro de degré

# 🇬🇧 Degree Number

```gdscript
d.degree_number = 1..7
```

Le degré 1 est la tonique.
Degree 1 is the tonic.

Chaque objet possède `to_string()` pour afficher ses caractéristiques.
Each object has `to_string()` to display its characteristics.

---

# 🇫🇷 Journalisation (LogBus)

# 🇬🇧 Logging (LogBus)

```gdscript
LogBus.debug(TAG, d.to_string())
```

Exemple / Example output:

```
Degree: ii° of key: D harmonic_minor(62), Duration: 4 beats, harmonic function: PD
kind: diatonic, realization: [1, 3, 5], inversion: 0
Roman Numeral: ii°, jazz chord: Edim, midi: [64, 67, 70]
```

---

# 🇫🇷 Autres propriétés du Degree

# 🇬🇧 Other Degree Properties

### 🇫🇷 Durée (beats)

### 🇬🇧 Duration (beats)

```gdscript
d.length_beats = 4
```

### 🇫🇷 Réalisation (notes de l’accord)

### 🇬🇧 Realization (chord tones)

```gdscript
d.realization = [1, 3, 5, 7]
```

### 🇫🇷 Renversement

### 🇬🇧 Inversion

```gdscript
d.inversion = 1
```

### 🇫🇷 Fonction harmonique

### 🇬🇧 Harmonic Function

```gdscript
d.set_harmonic_function("PD")   # Predominant
```

---

# 🇫🇷 Kind (type d’accord)

# 🇬🇧 Kind (chord type)

Par défaut / Default: **"diatonic"**

Peut être / Can be:

* N6 (sixte napolitaine) / Neapolitan sixth
* It+6, Fr+6, Ger+6 (sixte augmentée) / augmented sixth chords
* cad64 (accord cadentiel) / cadential 6/4
* sus2 / sus4
* add9 / add11
* melodic (une seule note) / single-note degree

Exemples / Examples:

```gdscript
d.set_N6()
d.set_aug6_It()
```

Kinds disponibles :
Available kinds:

```
melodic, diatonic, secondary,
It+6, Fr+6, Ger+6, It+6inv, Fr+6inv, Ger+6inv,
N6, chrom., cad64, sus2, sus4, add9, add11
```

---

# 🇫🇷 Altération du degré

# 🇬🇧 Altering the Degree

```gdscript
d.set_key_alteration(6, 1)   # raise degree 6
```

Permet, par exemple, de transformer minor → melodic minor.
For example, minor → melodic minor.

---

# 🇫🇷 Commentaire libre

# 🇬🇧 Free Comment

```gdscript
d.comment = "secondary dominant"
```

---

# 🇫🇷 Track

# 🇬🇧 Track

Créer une piste :
Create a track:

```gdscript
var tr = Track.new()
```

Ajouter un degré au 3ᵉ temps (index 2) :
Add a degree on beat 3 (index 2):

```gdscript
tr.add_degree(2, d)
```

Vélocité MIDI :
MIDI velocity:

```gdscript
d.velocity = 90
```

---

# 🇫🇷 Song

# 🇬🇧 Song

```gdscript
var mySong = Song.new()
```

### 🇫🇷 Signature rythmique

### 🇬🇧 Time signature

```gdscript
mySong.time_num = 3
mySong.time_den = 4
```

### 🇫🇷 Tempo

### 🇬🇧 Tempo

```gdscript
mySong.tempo_bpm = 140
```

### 🇫🇷 Objets MIDI

### 🇬🇧 MIDI objects

Dans *musicLib/Core* :
In *musicLib/Core*:

* Note
* ProgramChange
* MidiCC

---

# 🇫🇷 Visualisation (songTrackView)

# 🇬🇧 Visualization (songTrackView)

MusicLib permet d’afficher les pistes sous différentes formes :
MusicLib can display track content in different formats:

* chiffres romains / Roman numerals
* notes MIDI
* symboles jazz / jazz chord names
* clavier / keyboard view
* accords de guitare / guitar chord shapes


