# Plan d'implémentation du module Partimento dans MusicLib

Ce plan s'appuie sur la feuille de route fonctionnelle décrite dans `partimento brief/partimento_todo.md` et sur l'architecture actuelle de MusicLib (objets `Degree`, `HarmonicKey`, `Track`, générateurs de progressions). L'objectif est de proposer un moteur partimento modulable, capable de générer des progressions harmoniques à partir d'une basse schématique et d'outils de réalisation inspirés des pratiques napolitaines.

## Objectifs
- **Entrée** : lignes de basse structurées (degrés, altérations, métrique, tags de schéma/cadence).
- **Transformation** : application de règles de réalisation (règle de l'octave, cadences, séquences, contraintes de conduite des voix).
- **Sortie** : progressions d'accords (`Degree`/`Track`) annotées avec la provenance (schéma, cadence, variantes) pour réutilisation dans l'écosystème existant.

## Découpage des composants

### 1. Modèles de données
- `PartimentoBassEvent` : degré (1–7), altération, durée, position métrique, tags (cadence, séquence, modulation, pivot), note optionnelle si la basse est fournie en MIDI.
- `PartimentoBassLine` : séquence ordonnée de `PartimentoBassEvent` + tonalité (`HarmonicKey`). Fournit des helpers de navigation (mesure, segment, fenêtre contextuelle pour la règle de l'octave).
- `RealizationChoice` : proposition d'accord/renversement pour un événement de basse (type : triade/7e, renversement, figures 6/5/4/3, dissonances à résoudre, fonction harmonique suggérée).
- `RealizationGraph` : graphe ou liste d'états cumulés (chemins de réalisation possibles) avec score de conduite des voix et métadonnées.

### 2. Vocabulaire partimento
- `RuleOfTheOctaveBank` : tables d'harmonisation par degré, différenciées par mode (majeur, mineur), direction (montante/descendante) et contexte (milieu / approche cadence). Contient priorités et variantes.
- `CadenceBank` : modules greffables (authentique, rompue, évitée, phrygienne, cadence 6-4) avec conditions d'entrée/sortie et règles de résolution.
- `PatternBank` : schémas de basse typiques (descente conjointe, cercle des quintes, monte/fonte, passus duriusculus, etc.) décrits en degrés avec emplacements de variations et tonalités par défaut.
- `VoiceLeadingRules` : règles de scoring (pénalités pour quintes/octaves parallèles, sauts excessifs, non-résolution des 7e, mouvement conjoint favorisé dans les voix internes). Peut réutiliser `ParallelChecker.gd`.

### 3. Pipeline de réalisation
1. **Sélection/entrée** : récupérer une basse (depuis `PatternBank` ou entrée utilisateur) + tonalité (`HarmonicKey`).
2. **Pré-analyse** : marquer segments déclenchant la règle de l'octave, points cadentiels, options de séquence/modulation.
3. **Génération initiale** : pour chaque événement, générer des `RealizationChoice` via `RuleOfTheOctaveBank` + options contextuelles (cadence en approche, séquence en cours).
4. **Insertion de modules** : appliquer `CadenceBank` et autres macros (dominantes secondaires, échanges modaux) pour verrouiller certains noeuds du graphe.
5. **Exploration/évaluation** : explorer le `RealizationGraph` (DFS/BFS avec prunning) en scorant la conduite des voix (`VoiceLeadingRules`) et la cohérence fonctionnelle (T/PD/D déjà existants dans `Degree`).
6. **Enrichissement** : ajouter tensions (7e, 9e), diminutions/passaggi optionnels, variantes chromatiques si autorisées.
7. **Projection MusicLib** : convertir le chemin retenu en `Degree` + `Track`, en conservant des annotations (schéma, cadence, variante) dans des champs `comment` ou dédiés.

### 4. Intégration dans MusicLib
- **Nouveaux scripts** (proposés sous `musiclib/harmony/partimento/`):
  - `PartimentoBassEvent.gd`
  - `PartimentoBassLine.gd`
  - `RuleOfTheOctaveBank.gd`
  - `CadenceBank.gd`
  - `PatternBank.gd`
  - `RealizationEngine.gd` (orchestrateur pipeline)
  - `VoiceLeadingRules.gd`
- **Interopérabilité** :
  - Utiliser `HarmonicKey.gd`, `Degree.gd`, `Track` pour la représentation finale.
  - Réutiliser `ParallelChecker.gd` pour contrôler les mouvements parallèles.
  - Exposer des méthodes de génération de progressions compatibles avec `TonalProgressionHelper.gd` et `RockProgressionGenerator.gd` (ex. `PartimentoGenerator.generate_progression(pattern_name, key, options)` renvoyant `Track`).

## Étapes d'implémentation (itératif)
1. **Infrastructure & modèles** : créer les classes de base `PartimentoBassEvent`, `PartimentoBassLine`, `RealizationChoice`, `RealizationGraph`.
2. **Rule of the Octave** : implémenter `RuleOfTheOctaveBank` avec tables minimales (majeur/mineur, asc./desc.). Fournir API de lookup par degré + contexte.
3. **Cadences** : ajouter `CadenceBank` avec au moins authentique et phrygienne ; définir les règles de verrouillage des notes de basse et d'accords attendus.
4. **Générateur minimal** : `RealizationEngine.generate(track_len, key, pattern_name=nil)` capable de prendre une basse annotée et de produire une progression simple (triades, sans enrichissements) convertie en `Track`.
5. **Voice-leading** : brancher `ParallelChecker` et un scoring simple pour départager les chemins ; ajouter options de filtrage (rigoureux/souple).
6. **Bibliothèque de patterns** : renseigner quelques modèles emblématiques (descente conjointe, cercle des quintes, monte/fonte) dans `PatternBank`, avec tonalités par défaut et points cadentiels.
7. **Enrichissements** : ajouter tensions (7e/9e), dominantes secondaires, échanges modaux ; permettre des options de style (classique, galant, chromatique léger).
8. **Mode exercice** : prévoir une API qui retourne la basse seule ou la solution attendue pour un exercice (utile pour Godot UI).
9. **Documentation & exemples** : rédiger un guide d'utilisation (README dans le dossier partimento) avec exemples GDScript montrant la génération de progressions et l'intégration dans les scènes Godot existantes.

## Interfaces proposées (esquisse GDScript)
```gdscript
var key = HarmonicKey.new()
key.root_midi = 0
key.scale_name = "major"

var pattern = PartimentoPatternBank.get_pattern("descending_stepwise")
var bass = PartimentoBassLine.from_pattern(pattern, key)

var engine = RealizationEngine.new()
var options = {
    "style": "classical",
    "allow_sevenths": true,
    "voiceleading_strict": true
}
var result:Track = engine.realize(bass, options)
# result.degrees contient les Degree générés, annotés avec leur schéma/cadence
```

## Points de vigilance
- Garder la logique déterministe quand les options l'exigent (seed ou résolution greedy), mais autoriser un mode exploratoire/variations.
- Prévoir des hooks pour la métrique et la durée (compatibilité avec `rythm` s'il y a des contraintes de placement).
- Documenter les correspondances entre schémas partimento et objets MusicLib pour faciliter les contributions futures.

## Livrables attendus
- Dossier `musiclib/harmony/partimento/` avec les scripts listés et un `README.md` d'usage.
- Tests unitaires ou scénarios de génération démontrant :
  - application de la règle de l'octave sur une gamme montante/descendante;
  - réalisation d'une cadence authentique;
  - génération d'une progression complète à partir d'un pattern (au moins deux variantes).
```
