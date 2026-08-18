# 🎨 Adobe Universal Settings Backuper (Windows + macOS)

**Единый репозиторий** для бэкапа и восстановления “Adobe-среды” (настроек, рабочих пространств, кастомных плагинов, ScriptUI Panels, CEP-расширений) на **macOS** и **Windows** — с умными исключениями, чтобы не тащить кэши и “адобовский блоат”.

---

## ✨ Ключевые идеи

- **Backup/Restore**: делаем чистый бэкап и умеем вернуть всё на места.
- **Custom-only подход**:
  - **Плагины**: пытаемся сохранять **только сторонние/кастомные**, исключая стандартные папки Adobe (Keyframe/Format/Effects и т.п.).
  - **Скрипты**: для After Effects копируем **только** `ScriptUI Panels` (не все дефолтные скрипты).
- **Smart exclusions**: игнорируем кэши/логи/временные файлы и синхронизируемые облачные данные.

---

## 🛠️ Быстрый старт

### Root лаунчеры (самый простой способ)

- macOS: двойной клик по `run-macos.command`
- Windows: запуск `run-windows.cmd` (или `run-windows.cmd backup` / `run-windows.cmd restore "C:\path\to\backup"`)

### macOS (рекомендуется)

1) Сделай файл исполняемым один раз:

```bash
chmod +x macos/AdobeBackuper.command
```

2) Запуск:
- Двойной клик по `macos/AdobeBackuper.command`
- В меню выбери **Backup** или **Restore**

> При восстановлении в системные директории (`/Applications`, `/Library/...`) скрипт сам запросит **admin password**.

### Windows

#### Через `.cmd` лаунчеры (проще)

- Backup:
```cmd
windows\run-backup.cmd
```

- Restore (путь до папки бэкапа):
```cmd
windows\run-restore.cmd "windows\Backups\Adobe_Backup_2026-05-04_180000"
```

#### Напрямую PowerShell

```powershell
# Backup
.\windows\adobe-backup.ps1 -mode backup -dest .\windows\Backups

# Restore
.\windows\adobe-backup.ps1 -mode restore -dest ".\windows\Backups\Adobe_Backup_2026-05-04_180000"

# Dry-run (ничего не копирует, только показывает что будет сделано)
.\windows\adobe-backup.ps1 -mode restore -dest ".\windows\Backups\Adobe_Backup_2026-05-04_180000" -dryRun

# Опасно: зеркальный restore с удалениями (включать только если понимаешь последствия)
.\windows\adobe-backup.ps1 -mode restore -dest ".\windows\Backups\Adobe_Backup_2026-05-04_180000" -mirrorRestore
```

> Для восстановления в `C:\Program Files\...` чаще всего нужно запустить PowerShell **от имени администратора**.
>
> По умолчанию restore работает в **safe**-режиме (без удалений). Для “точного слепка” с удалениями есть флаг `-mirrorRestore` (опасно).

---

## 📦 Что сохраняем (в общих чертах)

### macOS
- `~/Library/Application Support/Adobe`
- `~/Library/Preferences` (только `*Adobe*` на верхнем уровне, включая папки `Adobe <App> <version> Settings` — там же лежат сохранённые Workspaces для Photoshop/Illustrator)
- `~/Documents/Adobe/Premiere Pro/*/Profile-*/Layouts` (+ `ArchivedLayouts`, `Mac`, `Win`) — сохранённые расклады интерфейса Premiere Pro
- `~/Documents/Adobe/After Effects */User Presets`
- `/Applications/Adobe */Plug-ins` (с исключениями стандартных)
- `/Applications/Adobe */Scripts/ScriptUI Panels` (только панели)
- `/Library/Application Support/Adobe/Common/Plug-ins`
- `/Library/Application Support/Adobe/CEP`

### Windows
- `%APPDATA%\Adobe\...` (настройки)
- `%USERPROFILE%\Documents\Adobe\...` (профили/лейауты и т.п.)
- `C:\Program Files\Adobe\...\Plug-ins` (custom-only попытка через исключения стандартных папок)
- `C:\Program Files\Adobe\...\Scripts\ScriptUI Panels` (только панели для AE)
- `C:\Program Files\Adobe\Common\Plug-ins\*\MediaCore`
- CEP:
  - `%APPDATA%\Adobe\CEP`
  - `C:\Program Files\Common Files\Adobe\CEP\extensions`
  - `C:\Program Files (x86)\Common Files\Adobe\CEP\extensions`

---

## 📁 Структура репозитория

```
Adobe-Universal-Settings-Backuper/
├── run-macos.command
├── run-windows.cmd
├── macos/
│   └── AdobeBackuper.command
├── windows/
│   ├── adobe-backup.ps1
│   ├── run-backup.cmd
│   └── run-restore.cmd
├── LICENSE
└── README.md
```

---

## 📄 Лицензия

MIT, см. `LICENSE`.
