# iOS interop — bridge patterns

Read this before writing any iOS-specific Compose interop. iOS is **Stable** in Compose Multiplatform since 1.8.0 (May 2025). Two directions: native views inside shared Compose, and shared Compose inside SwiftUI.

## 1. Native UIKit view inside shared Compose — `UIKitView`

`UIKitView` (and `UIKitViewController` for a whole controller) takes a `factory` lambda that builds the native object. Run on the main thread; size it with the Compose `modifier`.

```kotlin
// iosMain
import androidx.compose.ui.viewinterop.UIKitView
import platform.MapKit.MKMapView

@Composable
fun NativeMap(modifier: Modifier = Modifier) {
    UIKitView(
        factory = { MKMapView() },
        modifier = modifier.fillMaxSize(),
        update = { mapView -> /* mutate mapView on state change */ },
    )
}
```

## 2. Native view factory via a common interface + Koin (preferred)

Keep the shared screen platform-agnostic. Define the contract in `commonMain`, implement it in `iosMain`, inject with Koin. The common `@Composable` never imports `platform.*`.

```kotlin
// commonMain
interface NativeViewFactory {
    @Composable
    fun MapView(modifier: Modifier)
}

@Composable
fun MapScreen(factory: NativeViewFactory = koinInject()) {
    factory.MapView(Modifier.fillMaxSize())
}
```

```kotlin
// iosMain
class IosNativeViewFactory : NativeViewFactory {
    @Composable
    override fun MapView(modifier: Modifier) {
        UIKitView(factory = { MKMapView() }, modifier = modifier)
    }
}
// bind in a platformModule: single<NativeViewFactory> { IosNativeViewFactory() }
```

Why an interface over a raw `expect @Composable`: the Android/desktop targets get their own implementation (or a no-op), and you can fake it in `commonTest`.

## 3. Shared Compose inside a SwiftUI app — `ComposeUIViewController`

Expose a factory from `iosMain`, then wrap it in a SwiftUI `UIViewControllerRepresentable`.

```kotlin
// iosMain
import androidx.compose.ui.window.ComposeUIViewController

fun MainViewController() = ComposeUIViewController { App() }
```

```swift
// iosApp (SwiftUI)
import SwiftUI
import shared

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController()
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View { ComposeView().ignoresSafeArea(.all) }
}
```

## 4. ViewModel lifecycle on iOS

`androidx.lifecycle.ViewModel` runs in `commonMain`, but iOS has **no built-in `ViewModelStoreOwner`**, so nothing clears the VM for you.

- Inside a Compose-hosted screen, obtain VMs with `koinViewModel { }` (from `koin-compose-viewmodel`) — they are scoped to the Compose nav entry and cleared correctly.
- When a Kotlin VM must be observed from *SwiftUI* (not a Compose host), use **KMP-ObservableViewModel** so SwiftUI sees `@Published`-style updates, and clear it from the SwiftUI view's lifecycle.

## 5. Camera / system APIs

Same pattern: a common `interface` (`CameraController`, `SecureStorage`) with an `iosMain` impl using `platform.AVFoundation` / Keychain, injected via Koin. Reserve raw `expect`/`actual` for tiny, untestable leaves (device name, locale).
