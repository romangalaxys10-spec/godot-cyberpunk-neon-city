# 🌆 Cyberpunk Neon City 3D: Next-Gen Open-World Driving Simulator

[![Play in Browser](https://img.shields.io/badge/Play%20Online-Vercel%20Live-brightgreen?style=for-the-badge&logo=vercel)](https://godot-cyberpunk-city-ryzenadvanceds-projects.vercel.app)
[![Godot Engine](https://img.shields.io/badge/Godot%20Engine-4.7%2B-blue?style=for-the-badge&logo=godotengine)](https://godotengine.org)
[![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)](LICENSE)

> An open-world 3D urban driving simulator built from the ground up in **Godot 4.7**, featuring real-time procedural architectural generation, dynamic time-of-day illumination, realistic vehicle dynamics with Ackermann steering, pedestrian artificial intelligence, traffic flow, and custom photorealistic textures.

---

## 🎮 Play Live in Your Browser

Play the game instantly with WebGL/WebAssembly:
👉 **[godot-cyberpunk-city-ryzenadvanceds-projects.vercel.app](https://godot-cyberpunk-city-ryzenadvanceds-projects.vercel.app)**

---

## 📖 Architectural Thesis: Neuro-Symbolic Game Engineering with GLM-5.3 & Gemini 3.7

### 1. Abstract
The rapid evolution of Large Language Models (LLMs) and Multimodal Visual AI has opened unprecedented paradigms in autonomous game development. This project serves as a practical demonstration of **dual-model neuro-symbolic game synthesis**, where deep architectural reasoning, real-time procedural physics engines, and GPU-level render pipelines are co-designed and implemented using:
- **GLM-5.3** did **almost all the work**: the entire 2,600+ line `main.gd` — procedural 3.6 km city generation, all vehicle kinematics and progressive steering, traffic and pedestrian AI, weather, the cop chase, HUD, audio, and the WebAssembly export pipeline — **as well as the initial procedural texture generators** (asphalt, facades, sidewalks, car carbon, foliage).
- **Gemini 3.7 Flash** played one focused role: it **enhanced the visual look of the textures** — refining the PBR parameters, normal/roughness maps, and color grading of GLM-5.3's initial texture output. No game logic, no city generation, no gameplay code.

---

### 2. Technical System Architecture

```
                                  ┌───────────────────────────┐
                                  │      System Prompt &      │
                                  │    Design Directives      │
                                  └─────────────┬─────────────┘
                                                │
                       ┌────────────────────────┴────────────────────────┐
                       ▼                                                 ▼
        ┌──────────────────────────────┐                  ┌──────────────────────────────┐
        │   GLM-5.3 (ALMOST ALL WORK)  │                  │ Gemini 3.7 Flash (textures)  │
        │ - Procedural 3.6km City Grid │                  │ - Texture visual enhancement │
        │ - 4-Wheel Physics & Drifting │                  │ - PBR parameter refinement   │
        │ - Animated Pedestrian Agents │                  │ - Normal/roughness polish    │
        │ - Dynamic Traffic Pathing    │                  │ - ACES color-grading advice  │
        │ - INITIAL TEXTURES + GEN.PY  │                  │   (applied to GLM's output)  │
        └──────────────┬───────────────┘                  └──────────────┬───────────────┘
                       │                                                 │
                       └────────────────────────┬────────────────────────┘
                                                │
                                                ▼
                               ┌─────────────────────────────────┐
                               │       Godot Engine 4.7 Core     │
                               │   - MultiMeshInstance3D Arrays  │
                               │   - GL Compatibility / Vulkan   │
                               │   - Custom PBR Shaders & Foliage│
                               └────────────────┬────────────────┘
                                                │
                                                ▼
                               ┌─────────────────────────────────┐
                               │   WebAssembly / Vercel Edge     │
                               │  Cross-Origin Isolated Runtime  │
                               └─────────────────────────────────┘
```

#### A. Procedural City Generation & MultiMesh Optimization
A continuous **3.6 km urban grid** divided into distinct architectural districts:
- **Downtown / Financial District**: High-rise glass skyscrapers (up to 160m) rendered using optimized `MultiMeshInstance3D` batches to achieve 60 FPS on low-overhead mobile and integrated GPUs.
- **Neon Entertainment Core**: Emissive neon ribbons, volumetric street lighting, advertising billboards, and rain particle simulations.
- **Residential & Commercial Outskirts**: Mid-rise brutalist blocks, sidewalk curbs, street lamps, and lush street foliage.

#### B. Realistic Vehicle Kinematics & Progressive Steering
Unlike arcade-style physics, the driving model computes:
- Dynamic weight transfer (brake dive and acceleration squat).
- Progressive speed-dependent steering dampening and speed-sensitive lock for a natural, modern-feel turn.
- Realistic lateral tire slip, drift angles, and counter-steering recovery.
- Multi-component wheels consisting of rubber treads, alloy rims, illuminated cyber hubs, and static brake calipers with rolling wheel physics.

#### C. Autonomous Pedestrians & Urban Traffic
- **Pedestrian Simulation**: Multi-jointed human agents with natural walking kinematics, diverse skin tones, procedural wardrobe colors, collision response (knockdown + heat spike), and flee behavior when the car approaches fast.
- **Multi-Lane Traffic**: Autonomous civilian sedans and SUVs with headlights/taillights, **rear-end collision response**, and **follow-braking** so cars no longer pass through each other at junctions.
- **Police Pursuit**: Heading-relative intercept points so cops cut you off (instead of overshooting), all-direction spawning, and escalating heat.

#### E. v1.1 Feel & Visuals
- **Curbs are felt**: crossing a road edge now jolts the car (vertical impulse + damping) instead of stopping silently.
- **Skid marks** are laid on the asphalt during handbrake drifts (pooled, recycled quads).
- **Rooftop aviation beacons** pulse across the skyline at night.
- **Damage smoke** rises from the engine bay above 50% damage and intensifies toward wreck.
- **Recycled lamp light pools** project warm light onto the asphalt at night (a handful of shared omni lights track the nearest fixtures).
- **Day/Night consistency**: rain, clouds, stars and moon are now hidden in Daylight mode so the bright sky stays clean.

#### D. Dynamic Lighting: Day & Night Cycles
- Real-time atmospheric switching between **Daylight Mode** (high-altitude sun, skybox fill, specular asphalt reflections) and **Cyberpunk Night Mode** (deep volumetric fog, vibrant neon underglow, and high dynamic range bloom).

---

## 🕹️ Controls

| Action | Keyboard / Mouse | Gamepad |
| :--- | :--- | :--- |
| **Accelerate / Forward** | `W` / `Up Arrow` | Right Trigger / `R2` |
| **Brake / Reverse** | `S` / `Down Arrow` | Left Trigger / `L2` |
| **Steering (Left / Right)** | `A` / `D` / `Left` / `Right` | Left Analog Stick |
| **Handbrake / Drift** | `Space` | Button `A` / `Cross` |
| **Nitro Boost** | `Shift` / `E` | Button `X` / `Square` |
| **Toggle Day / Night Mode** | `L` | `D-Pad Up` |
| **Switch Camera (Chase / Hood)**| `C` / `V` | `R3` / Right Stick Click |
| **Pause / Reset** | `Esc` / `R` | `Start` / `Select` |

---

## 🛠️ Local Development & Running

### Prerequisites
- [Godot Engine 4.7+](https://godotengine.org) (Standard or .NET)
- Python 3.8+ (for procedural texture generators)

### Installation
```bash
# Clone the repository
git clone https://github.com/romangalaxys10-spec/godot-cyberpunk-neon-city.git
cd godot-cyberpunk-neon-city

# Generate high-resolution PBR textures
python3 generate_realistic_textures.py

# Launch directly in Godot
godot --path .
```

### Web Export & Deployment
To export the WebAssembly package for web hosting:
```bash
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
```

---

## 📜 Credits & Acknowledgments
- **Core Engine**: Godot Engine 4.7
- **AI Architecture & Code Synthesis (almost all work, incl. initial textures)**: GLM-5.3
- **Texture Visual Enhancement**: Gemini 3.7 Flash
- **Hosting**: Vercel Edge Network

## 📣 Share / Hashtags
**Primary set (for a post):**
`#GLM53 #GodotEngine #GameDevelopment #GenerativeAI #ZAI #AICoding #OpenSource #IndieGameDev #LLM #ProceduralGeneration`

**Extended set (more reach):**
`#GameDev #NeonCity #Cyberpunk #WebAssembly #CodeGeneration #DevTools #TechInnovation #AIAssisted #Gaming #SoftwareEngineering`

**LinkedIn sweet spot (3–5):** `#GLM53 #GodotEngine #GameDevelopment #GenerativeAI #OpenSource`

> **Play it live in your browser** — pin the link in any post: https://godot-cyberpunk-city.vercel.app

> A full copy-paste [LinkedIn post draft](LINKEDIN_POST.md) is included in this repo.

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
