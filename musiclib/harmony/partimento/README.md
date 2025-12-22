# Partimento — API publique & format `partimento_json`

Ce dossier propose l’infrastructure Partimento de MusicLib : objets de basse, banques de règles, moteur de réalisation et codecs. Les classes visées sont pensées pour être utilisées en GDScript (Godot 3.6).

## API publique (résumé)

### Basse
- `PartimentoBassEvent` : `degree:int`, `alter:int`, `length_beats:float`, `beat:float`, `figures:Array`, `tags:Array`, `comment:String`, `meta:Dictionary`.
- `PartimentoBassLine`
  - propriétés : `key:HarmonicKey`, `events:Array`, `time_signature:Dictionary` (`{"num":4, "den":4}`), `tempo_bpm:int` optionnel.
  - helpers : `from_pattern(pattern_name, key, options={})`, `from_partimento_json(dic:Dictionary)`, `to_partimento_json()`, `get_window(idx, size)`.

### Règles
- `RuleOfTheOctaveBank` / `CadenceBank` / `PatternBank`
  - `lookup(degree, context)` → options d’harmonisation
  - `get_pattern(name)` → structure convertible en `PartimentoBassLine`

### Réalisation
- `RealizationEngine`
  - `realize(bass_line:PartimentoBassLine, options={}) -> PartimentoRealization`
  - `realize_to_track(bass_line, options) -> Track`
- `PartimentoRealization`
  - propriétés : `degrees:Array` (`Degree` annotés), `choices:Array`, `debug:Array`
  - méthodes : `to_track(track_name="Partimento") -> Track`, `get_annotations() -> Dictionary`
- `PartimentoJsonCodec`
  - statiques `encode(bass_line|realization)` et `decode(dic)` pour valider/convertir le format `partimento_json`

## Format `partimento_json` (v1)
- Racine : `{"format":"partimento_json","version":"1.0","key":{},"bass":[]}`
- `key` : dictionnaire type `HarmonicKey.to_dict()` (`root_midi`, `scale_name`, altérations optionnelles)
- `time_signature` (optionnel) : `{ "num":4, "den":4 }`, `tempo_bpm` (optionnel int)
- `options` (optionnel) : `{ "style":"classical|galant|chromatic", "voiceleading_mode":"strict|lenient", "allow_sevenths":true }`
- `annotations` (optionnel) : `{ "schema":"romanesca", "cadence":"authentic" }`
- `bass` : tableau ordonné d’événements `{ "beat":0.0, "degree":1..7, "alter":-1|0|1, "length":1.0, "figures":["5","3"], "tags":["rule_of_octave:desc"], "comment":"pivot" }`
- Le moteur peut : (1) consommer ce format via `PartimentoJsonCodec.decode(...)` → `PartimentoBassLine`; (2) sérialiser une réalisation via `PartimentoJsonCodec.encode(realization)`

### Exemple complet
```json
{
  "format": "partimento_json",
  "version": "1.0",
  "key": {"root_midi": 0, "scale_name": "minor"},
  "time_signature": {"num": 4, "den": 4},
  "options": {"style": "classical", "voiceleading_mode": "strict", "allow_sevenths": true},
  "annotations": {"schema": "romanesca", "cadence": "authentic"},
  "bass": [
    {"beat": 0.0, "degree": 1, "alter": 0, "length": 1.0, "figures": ["5", "3"], "tags": ["rot:desc"], "comment": "tonic"},
    {"beat": 1.0, "degree": 7, "alter": -1, "length": 1.0, "figures": ["6", "5"], "tags": ["cadence:approach"], "comment": "leading tone"},
    {"beat": 2.0, "degree": 1, "alter": 0, "length": 2.0, "figures": ["5", "3"], "tags": ["cadence:authentic"], "comment": "resolution"}
  ]
}
```

## Exemple Godot (script minimal)
Ce script montre la construction d’une basse simple, sa réalisation en `Track` de `Degree` et le logging via `LogBus`.

```gdscript
extends Node

func _ready():
    var log := load("res://musiclib/LogBus.gd").new()
    log.set_verbose(true) # DEBUG + INFO

    # 1) Clé et basse
    var key := HarmonicKey.new()
    key.root_midi = 0
    key.scale_name = "major"

    var bass := PartimentoBassLine.new()
    bass.key = key
    bass.time_signature = {"num": 4, "den": 4}
    bass.events = [
        PartimentoBassEvent.new(0.0, 1, 0, 1.0, ["5","3"], ["rot:asc"], "tonic"),
        PartimentoBassEvent.new(1.0, 2, 0, 1.0, ["6","3"], ["rot:asc"], "step"),
        PartimentoBassEvent.new(2.0, 5, 0, 1.0, ["6","5"], ["cadence:approach"], "dominant"),
        PartimentoBassEvent.new(3.0, 1, 0, 1.0, ["5","3"], ["cadence:authentic"], "resolution")
    ]

    # 2) Réalisation -> Track
    var engine := RealizationEngine.new()
    var realization := engine.realize(bass, {"style": "classical", "voiceleading_mode": "strict"})
    var track:Track = realization.to_track("Partimento")

    # 3) Logging des degrés réalisés
    for ev in track.events:
        if ev.has("degree"):
            var deg:Degree = ev["degree"]
            log.debug("PARTIMENTO", "beat %s -> %s" % [ev.get("start", 0.0), deg.to_string()])
```

> Les chemins de chargement (`res://musiclib/...`) sont indicatifs ; adaptez-les à votre projet Godot.
