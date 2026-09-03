# NotchPrompter

Teleprompter para macOS que cuelga del notch. Pensado para grabar videos hablando a cámara: el texto queda justo bajo el lente.

## Requisitos

- macOS 14+
- Xcode 15+
- `brew install xcodegen`

## Build

```bash
xcodegen generate
xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData
open DerivedData/Build/Products/Debug/NotchPrompter.app
```

## Tests

```bash
xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS'
```

## Atajos (globales, con ⌃⌥)

| Atajo | Acción |
|---|---|
| ⌃⌥ Espacio | Play / pausa |
| ⌃⌥ ↑ / ↓ | Velocidad +10 / -10 |
| ⌃⌥ R | Volver al inicio |
| ⌃⌥ T | Mostrar / ocultar panel |

El guion se edita desde el ícono de la barra de menú y se guarda solo.

## Licencia

MIT. Ver [LICENSE](LICENSE).
