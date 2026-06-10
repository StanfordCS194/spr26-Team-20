allprojects {
    repositories {
        google()
        mavenCentral()
        // flutter_esp_ble_prov depends on com.github.espressif:* hosted on JitPack.
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some older plugins (e.g. flutter_esp_ble_prov 0.1.7) declare their Android
// package only via the legacy AndroidManifest `package` attribute and omit the
// `namespace`, which AGP 8+ requires. Inject the namespace from the plugin's
// group the moment the Android library plugin is applied (early enough that
// afterEvaluate ordering doesn't matter).
subprojects {
    plugins.withId("com.android.library") {
        val androidExtension =
            extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExtension != null && androidExtension.namespace == null) {
            androidExtension.namespace = project.group.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
