# Project setup — Gradle, source sets, module layouts

Full setup for the 2026 default KMP structure. Floors: CMP 1.11.0 (Jetpack Compose 1.11.1), Kotlin 2.1.0+ (2.2.20 recommended), K2 mandatory since CMP 1.8.0, AGP 9.0.

## Version catalog (`gradle/libs.versions.toml`)

```toml
[versions]
kotlin = "2.2.20"
compose = "1.11.0"
agp = "9.0.0"
androidx-lifecycle = "2.9.0"
koin = "4.0.0"
navigation = "2.9.0"

[plugins]
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
composeMultiplatform = { id = "org.jetbrains.compose", version.ref = "compose" }
composeCompiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }

[libraries]
lifecycle-viewmodel = { module = "org.jetbrains.androidx.lifecycle:lifecycle-viewmodel", version.ref = "androidx-lifecycle" }
navigation-compose = { module = "org.jetbrains.androidx.navigation:navigation-compose", version.ref = "navigation" }
koin-core = { module = "io.insert-koin:koin-core", version.ref = "koin" }
koin-compose-viewmodel = { module = "io.insert-koin:koin-compose-viewmodel", version.ref = "koin" }
```

## `shared/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.androidLibrary)
}

kotlin {
    androidTarget()
    jvm("desktop")
    listOf(iosArm64(), iosSimulatorArm64()).forEach { it.binaries.framework { baseName = "shared" } }
    // wasmJs { browser() }  // Beta — enable to pilot Web only

    sourceSets {
        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.components.resources)   // generated Res accessors
            implementation(libs.lifecycle.viewmodel)
            implementation(libs.navigation.compose)
            implementation(libs.koin.core)
            implementation(libs.koin.compose.viewmodel)
        }
        androidMain.dependencies { implementation(compose.preview) }
    }
}
```

## Source-set hierarchy

```text
commonMain
├── androidMain
├── desktopMain (jvm)
├── wasmJsMain (Beta)
└── iosMain (intermediate)
    ├── iosArm64
    └── iosSimulatorArm64
```

Use the intermediate `iosMain` for code shared by both iOS targets; only drop to `iosArm64`/`iosSimulatorArm64` for arch-specific cinterop.

## Module-layout variants

- **Mobile-only:** `shared` + `androidApp` + `iosApp`.
- **+ Desktop:** add `desktopApp` (`./gradlew :desktopApp:run`).
- **+ Web (Beta):** add `webApp` with the `wasmJs` target; do not promise parity.
- **Mixed native UI:** split `shared` into **`sharedLogic`** (all platforms, no Compose UI) + **`sharedUI`** (CMP platforms only). Native screens depend on `sharedLogic`; shared screens live in `sharedUI`.
- **+ Server:** add a root **`core`** module consumed by both clients and a JVM/Ktor server.

## Scaffolding

- New project: **kmp.new** or the Kotlin Multiplatform wizard (IntelliJ IDEA 2025.2.2+ / Android Studio Otter 2025.2.1+ with the KMP plugin).
- Existing Android app: Android Studio **Shared Module Template** (added May 2025) adds a KMP `shared` module in place.

## AGP 9.0 migration notes

The new default structure aligns with AGP 9.0. When migrating from the old single `composeApp` module: extract shared `@Composable`s/VMs into a `shared` library module, turn `composeApp` into a thin `androidApp` host that calls `setContent { App() }`, and move the iOS framework export into `shared`.

## Packaging

- Desktop: `./gradlew :desktopApp:packageDistributionForCurrentOS` (dmg/msi/deb). Needs **JDK 17+** for `jpackage`; desktop runtime floor is JDK 11+.
- iOS: archive the `iosApp` Xcode project (App Store signing is `swift-ios` territory).
- Web (Beta): `./gradlew :webApp:wasmJsBrowserDistribution`.
