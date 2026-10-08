# Oopsie Pawsie

Godot Project

## Structure

```text
.
├── assets/
│   ├── fonts/
│   ├── sounds/
│   └── sprites/
│
├── scenes/
│   └── mini_games/
│
├── scripts/
│   └── mini_games/
│
├── project.godot
├── .gitignore
└── README.md
```

### Where to put what?

- `scenes/mini_games/` → `.tscn` scenes
- `scripts/mini_games/` → `.gd` scripts
- `assets/sprites/` → sprites / textures
- `assets/sounds/` → music / SFX
- `assets/fonts/` → fonts

## Git

Don't work directly on `main`.

Create a branch:

```bash
git checkout -b feature/game-name
```

Example:

```bash
git checkout -b feature/memory
```

Then, once you're done:

```bash
git add .
git commit -m "Add memory mini-game"
git push -u origin feature/memory
```

Then → Pull Request into `main`.
