---

## ✨ Features

- Propagate GPS coordinates from selected photos to others.
- Works directly inside Lightroom Classic.
- Lightweight, self-contained Lua implementation.
- Preferences system for customizing behavior.
- Safe: does not overwrite Lightroom database directly; uses Lightroom SDK APIs.

---

## 🚀 Installation

1. Clone or download this repository.
2. Place the plugin folder somewhere permanent (e.g., `Documents/Lightroom Plugins/GPSPropagator.lrplugin`).
3. In **Lightroom Classic**:
   - Go to **File → Plug-in Manager**.
   - Click **Add**, then select the `.lrplugin` folder.
   - Enable the plugin.

---

## ⚡ Usage

1. Select one or more images with GPS coordinates.
2. Select target images without GPS data.
3. Run the plugin from the **Library → Plug-in Extras → GPS Propagator** menu.
4. The GPS coordinates will be copied to the selected target images.

---

## ⚙️ Preferences

The plugin reads/writes preferences from `prefs.lua`.  
You can customize defaults such as propagation modes or overwrite behavior.

---

## 🛠 Development

- Written in **Lua** for the Adobe Lightroom Classic SDK.
- Designed for Lightroom Classic 11+ (may work on earlier versions).
- Code style: minimal dependencies, portable across OS X and Windows.

---

## 📝 License

This plugin is released under the **GPL v2 or later** license.  
See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Pull requests and feature suggestions are welcome!  
If you encounter bugs, please open an issue with reproduction steps and Lightroom version info.

---
