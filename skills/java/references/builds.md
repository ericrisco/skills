# Build surface: Maven 3.9 & Gradle 9 (deep)

Versions as of 2026-06: **Maven 3.9.x is current stable** (Maven 4 is 4.0.0-rc-5, not GA —
prefer 3.9.x for production, watch for 4 GA). **Gradle 9.5.1** is current, requires Java 17+ to
run, and prefers the configuration cache. JDK target here is **Java 25 LTS** via `<release>` /
toolchain — adjust to 21 if you must run on the prior LTS.

## Maven: full pom.xml skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>payments</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.release>25</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <junit.version>5.11.4</junit.version>
    <assertj.version>3.27.0</assertj.version>
    <mockito.version>5.15.2</mockito.version>
  </properties>

  <dependencies>
    <dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId>
      <version>${junit.version}</version><scope>test</scope></dependency>
    <dependency><groupId>org.assertj</groupId><artifactId>assertj-core</artifactId>
      <version>${assertj.version}</version><scope>test</scope></dependency>
    <dependency><groupId>org.mockito</groupId><artifactId>mockito-core</artifactId>
      <version>${mockito.version}</version><scope>test</scope></dependency>
  </dependencies>

  <build><plugins>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId><artifactId>maven-compiler-plugin</artifactId>
      <version>3.13.0</version>
      <configuration>
        <release>25</release>
        <compilerArgs><arg>-Xlint:all</arg><arg>-Werror</arg></compilerArgs>
      </configuration>
    </plugin>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId>
      <version>3.5.2</version>
    </plugin>
  </plugins></build>
</project>
```

Build and test: `./mvnw -q verify` (commit the wrapper via `mvn wrapper:wrapper`). The wrapper
pins the Maven version per project; do not rely on a globally installed `mvn`.

### Preview flags (Maven)

For preview features (e.g. `StructuredTaskScope`, JEP 505 in 25), pass `--enable-preview` to
compiler, surefire, and the run command — all three or it fails at the next stage:

```xml
<configuration>
  <release>25</release>
  <compilerArgs><arg>--enable-preview</arg></compilerArgs>
</configuration>
<!-- surefire: -->
<configuration><argLine>--enable-preview</argLine></configuration>
```

```bash
java --enable-preview -jar target/payments-1.0.0.jar
```

### Toolchains (decouple build JDK from runtime JDK)

`~/.m2/toolchains.xml` plus `maven-toolchains-plugin` lets the build select a specific JDK
regardless of `JAVA_HOME`, so CI and laptops compile against the same version.

## Gradle: full build.gradle.kts

```kotlin
plugins {
    java
    application
}

group = "com.example"
version = "1.0.0"

java {
    toolchain { languageVersion = JavaLanguageVersion.of(25) }   // Gradle provisions/selects JDK 25
}

repositories { mavenCentral() }

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testImplementation("org.assertj:assertj-core:3.27.0")
    testImplementation("org.mockito:mockito-core:5.15.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<JavaCompile> { options.compilerArgs.addAll(listOf("-Xlint:all", "-Werror")) }
tasks.test { useJUnitPlatform() }
application { mainClass = "com.example.App" }
```

Build and test: `./gradlew check` (compile + test). Gradle 9 prefers the configuration cache —
enable with `org.gradle.configuration-cache=true` in `gradle.properties`. For preview features:
`options.compilerArgs.add("--enable-preview")` plus `tasks.test { jvmArgs("--enable-preview") }`
plus `application { applicationDefaultJvmArgs = listOf("--enable-preview") }`.

## Multi-module

- **Maven**: a parent `pom.xml` with `<packaging>pom</packaging>` and `<modules>`; share
  versions via `<dependencyManagement>` / a BOM so every module agrees on a version.
- **Gradle**: `settings.gradle.kts` with `include("api", "core")`; a `buildSrc` or version
  catalog (`gradle/libs.versions.toml`) centralizes versions.

## Dependency hygiene

- Pin versions; use a BOM (`<dependencyManagement>` / Gradle platform) so transitive versions
  agree.
- Check for updates: `mvn versions:display-dependency-updates` or the Gradle versions plugin.
- Scan for vulnerable dependencies in CI (OWASP dependency-check / your SCA tool).

## jlink / jpackage (note only — shipping lives in `deployment`)

`jlink` builds a minimal custom runtime image containing only the modules your app uses (small
container base); `jpackage` wraps it into a native installer (.dmg/.msi/.deb). For Dockerfiles,
CI, and release wiring see the `deployment` skill — this skill only points at the tools.
