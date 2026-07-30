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

### Run on desktop

With Odin on `PATH`:

```sh
odin run code
```

### Run on the web

With Odin and an activated [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) on `PATH`:

```sh
./build_web.sh
python3 -m http.server --directory build/web
```

Then open <http://localhost:8000>. The generated files in `build/web` are static and can be deployed to any static web host.
