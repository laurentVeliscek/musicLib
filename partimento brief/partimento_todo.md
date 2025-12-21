# Conversation — Partimento & intégration dans *musiclib*

## 1) Demande initiale
**User :** Explique moi le partimento

### Réponse
Le **partimento** (pluriel *partimenti*) est une méthode d’enseignement de la composition et de l’improvisation qui a surtout fleuri en Italie (notamment à Naples) entre le XVIIe et le début du XIXe siècle.

L’idée est simple : au lieu d’apprendre “la théorie” d’abord, on te donne une **basse écrite seule** (parfois avec quelques chiffres, parfois sans rien), et tu dois en faire de la musique complète au clavier : accords, contrepoint, mélodie, accompagnement, puis carrément des pièces.

#### À quoi ça ressemble ?
Un partimento, c’est souvent :
- une **ligne de basse** (comme une basse continue),
- des **indices implicites** (types de cadences, enchaînements typiques),
- parfois des **chiffres** (mais pas forcément),
- et une difficulté progressive : du simple accord à 4 voix → jusqu’à la fugue.

Tu joues (ou écris) dessus en “réalisant” :
- l’**harmonie** (quels accords ? quelles renversements ?),
- le **contrepoint** (comment les voix bougent),
- le **style** (mélodies, diminutions, imitation, etc.).

#### En quoi c’est différent d’une basse chiffrée “classique” ?
- La **basse chiffrée** sert surtout à accompagner (on te dit quoi mettre).
- Le **partimento** sert à **former le cerveau musical** : reconnaître des schémas, enchaîner, conduire les voix, inventer.  
  - Même sans chiffres, tu es censé “voir” ce qui est attendu.

#### Les “briques” fondamentales
Le partimento s’appuie sur des **schémas** qu’on internalise par la pratique :

- **Règle de l’octave** (*Rule of the Octave*)  
  Harmoniser une gamme montante/descendante à la basse selon le mode (majeur/mineur).

- **Cadences**  
  Basses-types qui appellent une résolution (par ex. mouvement vers V puis I), avec variantes.

- **Séquences et modèles**  
  Patterns de basses et progressions récurrentes (style galant, cycles, etc.).

- **Diminutions / passaggi**  
  Embellissements (notes de passage, appoggiatures, broderies) une fois la charpente solide.

#### Pourquoi c’était si puissant pédagogiquement ?
Ça entraîne simultanément :
- l’**oreille**,
- la **main**,
- la **grammaire** (harmonie + conduite des voix),
- et le **vocabulaire** (schémas réutilisables).

En gros : tu apprends la composition comme une langue, par **tournures** et **phrases**.

#### Comment on commence
Progression typique :
1) Harmoniser des basses simples (2 à 4 voix)  
2) Appliquer la règle de l’octave (majeur/mineur)  
3) Enchaîner des cadences dans plusieurs tonalités  
4) Ajouter des suspensions (7-6, 4-3, 9-8…)  
5) Ajouter une mélodie au soprano  
6) Passer à l’imitation / canons / fughetta  

---

## 2) Intérêt + question d’intégration
**User :** Ca m’intéresse beaucoup. Comment pourrais-je l’intégrer à musiclib ? Ne code rien, propose moi une implémentation des principes et comment je pourrais m’en servir pour construire des progressions d’accord

### Réponse
Intégrer l’esprit **partimento** dans *musiclib* peut se faire en ajoutant un niveau **“basse + schémas + règles de réalisation”** au-dessus des objets harmoniques existants, afin d’en faire un *moteur de construction* de progressions.

#### 1) Séparer “basse” → “charpente” → “progression”
Trois couches :

**A. Basse (entrée)**  
Une **BassLine** = suite de *degrés* et de *mouvements*, pas seulement des notes.
- (degré, altération, durée, position métrique)
- marqueurs optionnels : “cadence”, “modulation”, “séquence”, etc.

**B. Charpente (réalisation partimento)**  
Une **RealizationSkeleton** = pour chaque événement de basse, un ou plusieurs **choix d’accords/renversements** / figures (6, 6/5, 4/3…).
- inclut : Règle de l’octave, cadences, suspensions, séquences
- doit permettre plusieurs réalisations (branches), pas une seule sortie.

**C. Progression (sortie)**  
Une **ChordProgression** = suite d’accords (degrés / fonctions / renversements / tensions).
- utilisable pour playback, analyse, génération d’exos, etc.
- possibilité de garder la provenance : schéma, cadence, “technique” employée.

#### 2) Les “briques” partimento à stocker
**A. Schémas de basse (patterns)**  
- descente conjointe (1–7–6–5–4–3–2–1)
- basse en quintes (cercle tonal)
- monte/fonte (séquences), etc.
Chaque schéma décrit :
- forme en degrés (+ variantes)
- points forts attendus (cadence, dominante, etc.)
- emplacements pour variations

**B. Règle de l’octave (RO)**  
Table de réalisation par degré, dépendant de :
- mode (majeur/mineur)
- sens (montant/descendant)
- contexte (milieu / approche cadence)
RO = choix prioritaire + alternatives.

**C. Cadences (modules / macros)**  
Modules “greffables” :
- authentique, rompue, évitée
- phrygienne (mineur)
- cadence avec 6–4 cadentiel, etc.
Chaque cadence = conditions + sortie + options.

**D. Contraintes de conduite des voix (même sans 4 voix)**  
Un scoring de voice-leading pour départager des réalisations :
- éviter quintes/octaves parallèles (si style classique)
- préférer mouvements conjoints dans les voix internes
- limiter sauts de basse selon style
- gérer résolutions des dissonances (7e, 4–3, 9–8…)

#### 3) Pipeline concret pour générer des progressions
1) Choisir schéma de basse + tonalité  
2) Réaliser la charpente (RO + variantes contextuelles) → graphe de candidats  
3) Insérer/verrouiller une cadence à des points clés  
4) Résoudre les ambiguïtés via un score (voice-leading + fonction + style)  
5) Enrichissements : 7e/9e, dominantes secondaires, échanges modaux, modulations pivots

#### 4) Usages “au quotidien”
**A. Progression builder**  
Choix : schéma + style + densité (triades → 7e → tensions)  
Sorties : progression baseline + variations (cadentielle / chromatique / simplifiée)

**B. Mode exercice**  
Donner : basse seule ou basse + indices, puis comparer aux solutions.

**C. Construction d’un vocabulaire**  
Bibliothèque de segments taggés (schéma, cadence, tonalité, techniques)  
→ composition par assemblage de segments compatibles.

#### 5) Exemple d’usage (conceptuel)
Pour un rendu “classique tonal” en Do majeur :
1) Schéma : descente conjointe vers la tonique  
2) RO : harmonisations avec renversements “naturels”  
3) Cadence : pré-dominante → dominante → tonique sur la fin  
4) Variation : autoriser une dominante secondaire près de la dominante

Résultat : progression dérivée d’un mécanisme reproductible, pas d’un hasard.

---
