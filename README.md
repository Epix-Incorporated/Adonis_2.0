<div align="center">

![The Epix-Incorporated logo](https://images-ext-2.discordapp.net/external/aIBRjVfZJAGn2awfso3GY3kadhMQlVupqLEwnKGD3OE/https/repository-images.githubusercontent.com/55325103/2bed6800-bfef-11eb-835b-99b981918623?width=300&height=260)

<div>&nbsp;</div>

[![Roblox model](https://img.shields.io/static/v1?label=roblox&message=model&color=blue&logo=roblox&logoColor=white)](https://www.roblox.com/library/7510622625/ "The offical Adonis admin model.")
[![Roblox nightly](https://img.shields.io/badge/roblox-nightly-blueviolet?logo=roblox)](https://www.roblox.com/library/8612978896/ "The beta testing source code modulescript.")
[![LICENSE](https://img.shields.io/github/license/Epix-Incorporated/Adonis_2.0)](https://github.com/Epix-Incorporated/Adonis_2.0/blob/master/LICENSE "The legal LICENSE governing the usage of the admin system.")
[![releases](https://img.shields.io/github/v/release/Epix-Incorporated/Adonis_2.0?label=version)](https://github.com/Epix-Incorporated/Adonis_2.0/releases "Downloadable versions of the admin system.")
[![Discord server](https://img.shields.io/discord/81902207070380032?label=discord&logo=discord&logoColor=white)](https://dvr.cx/discord "A Discord server where people can discuss Adonis related stuff and talk.")
[![Lint](https://github.com/Epix-Incorporated/Adonis_2.0/workflows/lint/badge.svg)](https://github.com/Epix-Incorporated/Adonis_2.0/actions/workflows/lint.yml "Allows to check if the code of the admin system is valid without errors.")

</div>

---

Adonis is a community-maintained server moderation and management system created for use on the Roblox platform.

## ⚠️ NOTICE

This version of Adonis is a **WORK IN PROGRESS** and is missing many features. For the current and supported version, see the [Adonis 1.0 repository](https://github.com/Epix-Incorporated/Adonis).

⚠️ **DO NOT USE ADONIS 2.0 IN A PRODUCTION ENVIRONMENT! IT WILL NOT WORK.** ⚠️

**The following information on this page may not be accurate.**

## ✨ Installation {#installation}

(WIP)

If you get stuck, feel free to ask for assistance in our [Discord server](https://discord.gg/H5RvTP3).

### Method 1 (recommended): Official Roblox Model {#method-1}

1. [Take a copy](https://www.roblox.com/library/7510622625/) of the Adonis loader model from the Roblox library
2. Insert the model into Studio using the Toolbox into `ServerScriptService`

### Method 2: GitHub Releases {#method-2}

1. Download the `rbxm` file snapshot from the [latest release](https://github.com/Epix-Incorporated/Adonis_2.0/releases/latest)
2. Import the model file into Studio
  * Note: By default, snapshots included in releases have [`DebugMode`](#debug-mode) enabled.

### Method 3: Filesystem {#method-3}

1. Download the repository to your computer's file system
2. Install and use a plugin like [Rojo](https://rojo.space/) to compile Adonis into a `rbxmx` file
  * If using Rojo, you can run `rojo build /path/to/adonis -o Adonis.rbxmx` to build a `rbxmx`
3. Import the compiled model file into Studio
  * Note: By default, loaders compiled from the repository have [`DebugMode`](#debug-mode) enabled. **This method compiles the *bleeding edge* version of Adonis, which may be unstable.**

## 🛠️ Debug Mode {#debug-mode}

The Adonis loader provides a `DebugMode` option which will load a local copy of the `MainModule` rather than fetching the latest version. This could be useful if you want to stay on a particular version of Adonis or want to maintain a custom version for your game. Debug mode expects the `MainModule` to share the same parent with the loader model (e.g. both should be in `ServerScriptService`). **By default, snapshots provided in  releases have `DebugMode` enabled.**

### Toggling debug mode {#toggling-debug-mode}

1. Open `Adonis_Loader` > `Loader` > `Loader`
2. Change `DebugMode` at the end of the `data` table to the desired value (e.g. `DebugMode = false`)

## 🔗 Links {#links}

* Official Adonis Loader: <https://www.roblox.com/library/7510622625/Adonis-Loader>
* Official MainModule: <https://www.roblox.com/library/7510592873/Adonis-MainModule>
* Documentation: <https://github.com/Epix-Incorporated/Adonis_2.0/wiki>
* Discord Server: <https://discord.gg/H5RvTP3>

## ⭐ Contributing {#contributing}

The purpose of this repository is to allow others to contribute and make improvements to Adonis. Even if you've never contributed on GitHub before, we would appreciate any contributions that you can provide.

### 📜 Contributing Guide {#contributing-guide}

Read the contributing guide to get a better understanding of our development process and workflow, along with answers to common questions related to contributing to Adonis.

### ⚖️ License {#license}

Adonis is available under the terms of [the MIT license](https://github.com/Epix-Incorporated/Adonis_2.0/blob/master/LICENSE).
