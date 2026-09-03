# NotchPrompter — Diseño

Fecha: 2026-09-03

## Objetivo

Teleprompter nativo para macOS que cuelga del notch del MacBook, para grabar videos hablando a cámara con la mirada a 1-2 cm del lente. Scroll automático con velocidad ajustable, controlado por atajos globales.

Fuera de alcance en esta versión: seguimiento por voz, control manual línea a línea, exclusión del screen sharing, atajos configurables, archivos o sync del guion, ajuste de tipografía.

## Stack

- Swift 5.9+, SwiftUI para contenido, AppKit para la ventana.
- macOS 14 o superior (usa `CADisplayLink` de `NSScreen`).
- Proyecto Xcode generado con XcodeGen desde `project.yml`.
- Sin dependencias externas.

## 1. Ventana sobre el notch

App sin Dock ni ventana principal (`LSUIElement = true`). Ícono en la barra de menú.

`PrompterPanel: NSPanel`:

- `styleMask = [.borderless, .nonactivatingPanel]`.
- `level = .statusBar + 1`.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`.
- `ignoresMouseEvents = true` mientras reproduce.
- Contenido: `NSHostingView` con `PrompterView`, fondo negro, esquinas inferiores redondeadas 16 pt.

Geometría (`NotchGeometry`), función pura sobre valores extraídos de `NSScreen`:

- Entrada: `screenFrame`, `safeAreaInsets.top`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`.
- Ancho del notch = `topRight.minX - topLeft.maxX` cuando ambas áreas existen; si no hay notch, ancho 0.
- Panel: 560 x 130 pt, centrado en X sobre el centro del notch (o de la pantalla si no hay notch), borde superior pegado al borde superior de la pantalla.
- Se recalcula al recibir `NSApplication.didChangeScreenParametersNotification`.

## 2. Motor de scroll

`PrompterEngine: ObservableObject`, sin dependencias de UI.

Estado:

- `text: String`
- `offset: CGFloat` (puntos desplazados hacia arriba, parte en 0)
- `speed: Double` en pt/s, rango 20...200, default 60, paso 10
- `isPlaying: Bool`
- `contentHeight: CGFloat` (lo informa la vista)
- `viewportHeight: CGFloat`

Reloj: protocolo `FrameClock` con `start(onTick: (dt) -> Void)` y `stop()`. Implementación real con `NSScreen.displayLink`; en tests se llama `tick(dt:)` a mano.

Reglas:

- `tick(dt)`: si `isPlaying`, `offset += speed * dt`. Si `offset >= contentHeight`, `offset = contentHeight` y `isPlaying = false`.
- `togglePlay()`, `increaseSpeed()`, `decreaseSpeed()` (clamp al rango), `reset()` (offset 0, pausa).
- `text` y `speed` se persisten en `UserDefaults` al cambiar. `offset` no.

Render (`PrompterView`):

- `Text` completo dentro de `GeometryReader`, `.offset(y: -offset)`, `.clipped()`.
- Padding superior igual a `viewportHeight` para que la primera línea entre desde abajo.
- SF Pro 34 pt, blanco sobre negro, interlineado 1.3, sin `minimumScaleFactor`.
- Degradado negro arriba y abajo; línea bajo el lente a brillo completo.
- En pausa, texto a 60 % de opacidad.
- Al cambiar velocidad, número en la esquina durante 1 s.
- Texto vacío: "Escribe tu guion desde el menú" en gris.

## 3. Controles

Atajos globales con `RegisterEventHotKey` (Carbon), sin permiso de Accesibilidad, fijos:

| Atajo | Acción |
|---|---|
| ⌃⌥ Espacio | Play / pausa |
| ⌃⌥ ↑ / ↓ | Velocidad +10 / -10 |
| ⌃⌥ R | Volver al inicio |
| ⌃⌥ T | Mostrar / ocultar panel |

Editor de guion: ventana normal con `TextEditor`, guarda solo. Al cerrarla el panel se actualiza y `offset` vuelve a 0.

Menú de barra: Editar guion, Mostrar/ocultar panel, submenú Atajos (referencia), Salir.

Errores: si falla el registro de un hotkey, se marca en el menú y el resto sigue. Nada más puede fallar de forma relevante.

## 4. Estructura

```
NotchPrompter/
├── project.yml
├── NotchPrompter/
│   ├── NotchPrompterApp.swift
│   ├── Window/PrompterPanel.swift
│   ├── Window/NotchGeometry.swift
│   ├── Engine/PrompterEngine.swift
│   ├── Engine/FrameClock.swift
│   ├── Views/PrompterView.swift
│   ├── Views/ScriptEditorView.swift
│   ├── Input/HotKeys.swift
│   └── Info.plist
└── NotchPrompterTests/
    ├── PrompterEngineTests.swift
    └── NotchGeometryTests.swift
```

## 5. Pruebas

Unitarias (XCTest):

- `PrompterEngine`: avance `speed * dt`; se detiene al final; clamp de velocidad 20...200; reset a 0 y pausa; no avanza en pausa.
- `NotchGeometry`: MacBook Pro 14" con notch (panel centrado sobre el notch, pegado arriba); monitor externo sin notch (centrado en pantalla).

Manuales:

1. QuickTime grabando cámara: el panel se ve encima y los atajos funcionan sin activar la app.
2. QuickTime en fullscreen: el panel sigue visible.
3. Leer un guion de 1 minuto a velocidad 60 y calibrar el default.
