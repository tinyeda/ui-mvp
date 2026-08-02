# MVP for TinyEDA studio

This is an MVP (Minimum Viable Product) for TinyEDA studio, an integrated design environment for digital and analog chip design.

## Scope

### What does this demonstrate (scope of the demo)

With this demo, we are trying to visualise how an **integrated** environment would look for IC design.
What we want to give users:-
1. Higher development velocity due to integrating all tools within one environment reducing communication and compatibility overhead.
2. Easy learning curve for people to switch over from other tools.
3. Make it about the **design** and **designer**, so designers aren't spending time playing around with the tool they're actually working on their design (something that gets out of the way of the designer to help them design.)
4. Make it very easy to collaborate across teams and simplify the submission process all the way from PDK registration to final signoff and sending in GDS for tapeout.

### What does this not demonstrate
1. The speedup from developing custom implementations of algorithms used in the Physical Design process.
2. No SA / RL algorithms for digital design PD, and schematic / design intent to layout for analog design.
3. No PDK integration and end to end signoff flow to go from getting pdk to submitting GDS.

This demo primarily demonstrates the ux of such an interface not internals, for some internals we will just mock results or maybe plugin some open source tools for now while the core digital RTL->GDS workflow and analog schematic -> GDS workflow is created.

## Development

The application uses Odin's `vendor:raylib` package as its platform and renderer layer and [rlImGui](https://github.com/raylib-extras/rlImGui) to connect raylib to Dear ImGui. UI code directly uses the generated ImGui bindings. The repository ships the ImGui/rlImGui static libraries needed by its supported targets, so normal application builds do not compile C++ or require CMake.

The shared application lifecycle and UI live in `code/app`. Desktop and web have small entry points that provide their different main-loop and runtime setup, while calling the same `app.Init`, `app.Frame`, and `app.Shutdown` procedures.

Panel inventory and Dear ImGui's docking layout are restored across runs. Native builds save `workspace.json` and `imgui.ini` under the operating system's per-user configuration directory in a `TinyEDA` folder. Web builds store the equivalent data in the site's browser `localStorage`. Packaged application resources remain read-only; user layout changes are always written to per-user storage.

The Text Editor panel opens general text files from the project explorer, keeps one tab per file, and marks edited tabs with an unsaved dot. Use its Save button or `Ctrl+S`/`Cmd+S` to save the active file. Desktop saves write to the selected filesystem path. All web browsers use the same portable project model: imports, newly created files, and saved edits are stored locally in IndexedDB and restored on later visits to the same site. Browser storage can be cleared by the browser or user and is not a backup, so the Project Explorer provides an **Export Project (.zip)** action. Browser saves update TinyEDA's local project copy rather than modifying the imported operating-system folder.

### Run on desktop

Clone the ui-mvp repository and download lfs objects:

```sh
git clone https://github.com/tinyeda/ui-mvp.git
cd ui-mvp
git lfs install
git lfs pull
```

Install the Odin compiler [following instructions from the Odin website](https://odin-lang.org/docs/install/#from-source)

```sh
odin run code
```

### Run on the web

With the Odin compiler installed, install [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) and run the web build script:

```sh
./build_web.sh
python3 -m http.server --directory build/web --bind localhost:8000
```

Then open <http://localhost:8000>. The generated files in `build/web` are static and can be deployed to any static web host.

### Deploy to GitHub Pages

Pushes to `main` build and deploy the production application through `.github/workflows/pages.yml`. Other branches deploy to `/<branch-name>/`, and pull requests deploy to `/pr-<number>/` with a sticky preview link added to the pull request. Branch previews are replaced on every push and removed when the branch is deleted; pull request previews are removed when the pull request closes.

Before the first deployment, set **Settings → Pages → Build and deployment → Source** to **Deploy from a branch**, then select the `gh-pages` branch and `/ (root)` directory.
