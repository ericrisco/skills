# Native modules — full walkthrough

When a maintained npm package already bridges the native API, use it and stop. Author a module only when there is no maintained wrapper, you need an API the wrapper doesn't expose, or you're shipping the SDK yourself.

## Decision recap

- **Expo Modules API** — Swift/Kotlin, no codegen, ergonomic DSL. Requires the app to use Expo. Lowest boilerplate; the default for Expo apps.
- **Turbo Module** — codegen from TypeScript/Flow spec files. The RN-default path; works in bare RN. More boilerplate, fully typed across the boundary.
- **Nitro Modules** — emerging high-performance option for hot paths. Weigh maturity before betting a shipping feature on it.

## Expo Modules API — full example

A module that exposes a function, a constant, an event, and a native view.

```swift
// ios/HealthModule.swift
import ExpoModulesCore

public class HealthModule: Module {
  public func definition() -> ModuleDefinition {
    Name("HealthModule")

    Constants(["isAvailable": HKHealthStore.isHealthDataAvailable()])

    Events("onStepsUpdate")

    AsyncFunction("readSteps") { (start: Double, end: Double) -> Int in
      // query HealthKit, return a step count
      return 0
    }

    View(HealthChartView.self) {
      Prop("range") { (view: HealthChartView, range: String) in
        view.setRange(range)
      }
    }
  }
}
```

```kotlin
// android/src/main/java/com/app/HealthModule.kt
package com.app

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class HealthModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("HealthModule")
    Constants("isAvailable" to HealthConnectClient.isAvailable())
    Events("onStepsUpdate")
    AsyncFunction("readSteps") { start: Double, end: Double ->
      // query Health Connect, return a step count
      0
    }
    View(HealthChartView::class) {
      Prop("range") { view: HealthChartView, range: String -> view.setRange(range) }
    }
  }
}
```

```ts
// src/HealthModule.ts — the typed JS surface
import { requireNativeModule, requireNativeViewManager } from 'expo-modules-core';

type HealthNative = {
  isAvailable: boolean;
  readSteps(start: number, end: number): Promise<number>;
  addListener(event: 'onStepsUpdate', cb: (e: { steps: number }) => void): { remove(): void };
};

const Native = requireNativeModule<HealthNative>('HealthModule');

export const isHealthAvailable = Native.isAvailable;
export const readSteps = (start: Date, end: Date) =>
  Native.readSteps(start.getTime(), end.getTime());
export const HealthChartView = requireNativeViewManager('HealthModule');
```

Notes:
- `AsyncFunction` returns a Promise to JS without blocking the UI thread; use `Function` only for cheap synchronous calls.
- `Constants` are read once at module init — don't use them for values that change.
- Events: emit from native with `sendEvent("onStepsUpdate", ...)`; JS subscribes via `addListener`.

## Turbo Module — codegen spec walkthrough

Turbo Modules generate native interfaces from a TS spec. The spec file name must start with `Native`.

```ts
// specs/NativeHealth.ts
import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  readonly isAvailable: () => boolean;
  readSteps(start: number, end: number): Promise<number>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Health');
```

Configure codegen in `package.json`, then `pod install` (iOS) / build (Android) runs codegen and emits the C++/ObjC++/Java interfaces you implement:

```json
{
  "codegenConfig": {
    "name": "RNHealthSpec",
    "type": "modules",
    "jsSrcsDir": "specs"
  }
}
```

You then implement the generated protocol in Objective-C++/Swift and the generated abstract class in Java/Kotlin. The contract is enforced at build time — a signature mismatch fails codegen rather than crashing at runtime.

## Packaging & autolinking

- Expo Modules in a library: ship an `expo-module.config.json` so autolinking discovers it; the host app needs no manual linking.
- Turbo Module in a library: a `react-native.config.js` / podspec drives autolinking.
- Test on a **real device** for anything touching sensors, permissions, or background work — simulators lie about HealthKit, Bluetooth, and camera.
- Version-gate native APIs (HealthKit availability, Health Connect install state) before calling; expose the gate as a JS-readable constant so the UI can degrade gracefully.
