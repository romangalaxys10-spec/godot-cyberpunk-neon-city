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
- **GLM-5.3**: Serving as the primary **System Architect & Logic Engine** for core GDScript algorithmic systems, multi-body kinematics, spatial partitioning, Ackermann steering curves, and multi-mesh instance management.
- **Gemini 3.7 (Vision & Multimodal Intelligence)**: Serving as the **Visual & Material Director**, guiding PBR texture synthesis, normal/roughness map formulations, atmospheric scattering coefficients, and ACES Filmic color-grading curves.

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
        │       GLM-5.3 Architecture   │                  │     Gemini 3.7 Visual Intel  │
        │ - Procedural 3.6km City Grid │                  │ - PBR Texture Parameter Gen │
        │ - 4-Wheel Physics & Drifting │                  │ - ACES Filmic Color Grading  │
        │ - Animated Pedestrian Agents │                  │ - Atmospheric Fog & Lighting │
        │ - Dynamic Traffic Pathing    │                  │ - High-Poly Car Styling      │
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

#### B. Realistic Vehicle Kinematics & Ackermann Steering
Unlike arcade-style physics, the driving model computes:
- Dynamic weight transfer (brake dive and acceleration squat).
- Progressive speed-dependent steering dampening with Ackermann low-speed authority.
- Realistic lateral tire slip, drift angles, and counter-steering recovery.
- Multi-component wheels consisting of rubber treads, alloy rims, illuminated cyber hubs, and static brake calipers with rolling wheel physics.

#### C. Autonomous Pedestrians & Urban Traffic
- **Pedestrian Simulation**: Multi-jointed human agents with natural walking kinematics, diverse skin tones, procedural wardrobe colors, and collision-aware sidewalk roaming.
- **Multi-Lane Traffic**: Autonomous civilian sedans and SUVs traversing intersection networks with functioning headlights and taillights.

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
- **AI Architecture & Code Synthesis**: GLM-5.3
- **Vision & Aesthetic Guidance**: Gemini 3.7
- **Hosting**: Vercel Edge Network

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
