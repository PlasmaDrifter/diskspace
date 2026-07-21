# Disk Space Monitor Widget

[![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-3152A0?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/UI-QML%2FQt6-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![Category](https://img.shields.io/badge/Storage%20Monitor-5856D6?style=for-the-badge&logo=harddrive&logoColor=white)](https://github.com/PlasmaDrifter)
[![License](https://img.shields.io/badge/License-LGPL%202.1+-blue.svg?style=for-the-badge)](LICENSE)

A clean, modern disk usage gauge for root, home, and external storage mount points in KDE Plasma 6.

---

## Previews

![Disk Space Monitor Widget Preview](diskspace.png)

![Disk Space Monitor Widget Preview](desktop-1.png)

---

## Features

- **Real-time**: disk space usage percentages and free space display
- **Multi-partition**: support (Root, Home, External drives)
- **Dynamic**: color indicators for low disk space warnings
- **Clean**: visual bar graphs

## Requirements

- **Environment**: KDE Plasma 6.0 or higher
- **Framework**: Qt6 QML / Plasma Applet API

## Installation

### Option 1: Git Clone (Recommended)
```bash
mkdir -p ~/.local/share/plasma/plasmoids/
git clone https://github.com/PlasmaDrifter/diskspace.git ~/.local/share/plasma/plasmoids/local.widget.diskspace
```

### Option 2: Plasma Package Installer
```bash
kpackagetool6 -i ~/.local/share/plasma/plasmoids/local.widget.diskspace
```

Then right-click your desktop or panel $\rightarrow$ **Add Widgets...** and search for the widget name.

## Credits & License

- **Author / Maintainer**: PlasmaDrifter
- **License**: Licensed under the [LGPL 2.1+](LICENSE).
