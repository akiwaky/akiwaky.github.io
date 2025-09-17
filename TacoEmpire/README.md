# Taco Empire – Sprint 1 Vertical Slice

Bienvenidx al prototipo express de **Taco Empire**, construido en Godot 4.3 con vibes CDMX, low poly mental y economía data-driven. Este slice cubre el loop base: compra maíz, produce tortillas, arma tacos sencillos y véndelos mientras surfeas la demanda de la calle.

## Cómo correrlo
1. Instala [Godot 4.3](https://godotengine.org/).
2. Abre el proyecto (`TacoEmpire/project.godot`).
3. Lanza la escena principal `res://scenes/main/Main.tscn` o simplemente presiona `F5`.
4. Juega en 1080p; el setup apunta a 60 FPS sin spikes >10 ms.

### Controles rápidos
- Selecciona módulos en el HUD (botones `Comal`, `Mesa`, `Mostrador`).
- Haz click izquierdo sobre el mapa para colocar el módulo seleccionado.
- `ESC` limpia la selección y oculta el ghost.
- Botón “Comprar maíz x10 🌽” incrementa inventario.
- Botón “Mejoras 🌮” abre/cierras la UI de upgrades.

## Carpeta y escenas clave
```
TacoEmpire/
├── project.godot
├── data/            # JSON para módulos, recetas, demanda, upgrades, tutorial
├── scenes/
│   ├── main/        # Main.tscn + flujo central
│   ├── hud/         # HUD.tscn (CanvasLayer + panel de control)
│   ├── ui/          # UpgradesPanel.tscn, UpgradeCard.tscn
│   └── tutorial/    # Tutorial.tscn para onboarding express
└── scripts/
    ├── systems/     # Economy, DemandSimulator, PlacementSystem, Production, SaveLoad, GameState, EventManager
    ├── ui/          # HUD, UpgradesPanel, TutorialController
    └── world/       # MainController, PlacementGhost
```

## Escenas principales
| Escena | Propósito |
|--------|-----------|
| `Main.tscn` | Orquesta el mundo, conecta sistemas y administra input/placement.
| `HUD.tscn` | HUD minimalista con cash, hora, demanda, inventario, palette de módulos y acciones.
| `UpgradesPanel.tscn` | Tarjetas de upgrades con compras persistentes.
| `Tutorial.tscn` | Overlay temporal (≈40 s) con pasos básicos.

## Datos de balance (JSON-driven)
### Módulos (`data/modules.json`)
| ID | Nombre | Rol | Coste | Input → Output | Tiempo (s) | Throughput base |
|----|--------|-----|-------|----------------|------------|-----------------|
| `comal_basic` | Comal Callejero | Producción | $150 | Maíz → Tortilla | 2.0 | 0.5 tortilla/s |
| `prep_table` | Mesa de Preparación | Ensamblado | $200 | Tortilla → Taco | 1.5 | 0.66 taco/s |
| `front_counter` | Mostrador Alegre | Venta | $220 | Taco → 💸 | 1.0 | 1 venta/s (limitada por demanda) |

### Recetas & Recursos (`data/recipes.json`)
- Maíz cuesta $2 por unidad.
- 1 tortilla = 1 maíz, 1 taco = 1 tortilla.

### Demanda (`data/demand.json`)
| Franja | Horario | Afluencia base (clientes/min) | Multiplicador precio |
|--------|---------|-------------------------------|----------------------|
| Desayuno | 06:00–11:00 | 10 | 1.0 |
| Comida | 12:00–16:00 | 20 | 1.2 |
| Nocturno | 17:00–23:00 | 30 | 1.4 |
- Conversión objetivo: 60%.
- Evento “Llovizna Chilanga”: 2% prob/min, dura 60 s, afluencia ×0.9.

### Upgrades (`data/upgrades.json`)
| ID | Nombre | Coste | Efecto |
|----|--------|-------|--------|
| `comal_plus` | Comal Plus | $250 | Throughput del comal ×1.1 |
| `salsa_legendaria` | Salsa Legendaria | $300 | Precio promedio ×1.05 |
| `letrero_neon` | Letrero Neón | $400 | Demanda efectiva ×1.15 |

## Sistemas clave
- **GameState.gd**: Autoload que coordina economía, demanda, placement, producción y guardado JSON (`user://taco_empire_save.json`).
- **Economy.gd**: Maneja cash, inventario y aplicación de upgrades. Sin magic numbers, todo viene de JSON.
- **DemandSimulator.gd**: Interpola franjas, aplica clima y empuja snapshots al HUD/Production.
- **PlacementSystem.gd**: Grid fake-isométrico, preview/confirm y restauración desde save.
- **Production.gd**: Pipeline maíz → tortilla → taco → venta con budget de demanda por segundo.
- **SaveLoad.gd**: Serializa estado económico, módulos y upgrades; formato JSON legible.
- **TutorialController.gd**: Secuencia guiada de 5 pasos (~40 s) con botón “Siguiente ➡”.

## Guardado
- Se autoguarda al iniciar nueva partida, comprar maíz, colocar/quitar módulos y comprar upgrades.
- Archivo: `user://taco_empire_save.json`. Bórralo para reiniciar desde cero.

## Mini test plan (manual)
1. **Loop básico**: Comprar 10 maíces, colocar 1 comal, 1 mesa y 1 mostrador, esperar a que se produzcan y vendan tacos; verificar cash > $500 tras ventas.
2. **Demanda dinámica**: Avanzar reloj hasta franja nocturna y confirmar aumento de afluencia (HUD muestra ≥30 pax/min) y ventas más rápidas.
3. **Evento Llovizna**: Forzar espera hasta que aparezca banner ☔ y confirmar reducción temporal de demanda (~10%).
4. **Upgrades persistentes**: Comprar “Comal Plus”, reiniciar el juego y verificar que el upgrade permanece aplicado (botón deshabilitado, producción más veloz).
5. **Guardado/carga**: Colocar módulos en diferentes celdas, salir del juego, reabrir y validar que las posiciones se restauran.

## Next steps sugeridos para Sprint 2
1. **Staff & turnos**: Introducir personajes (cocinero, mesero) con energía/descansos para modular throughput.
2. **Nuevas recetas**: Añadir suadero/pastor con toppings y requerimientos múltiples (salsa, guacamole) más gestión de proveedores.
3. **Expansión geográfica**: Desbloquear segunda zona (plaza, mercado interior) con distinta demanda y clima.

¡Listo para seguir construyendo este imperio taquero con flow spanglish y mucho sazón! 🌮
