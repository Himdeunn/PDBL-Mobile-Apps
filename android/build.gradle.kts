allprojects {
    repositories {
        google()
        mavenCentral()
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- BAGIAN PERBAIKAN ERROR ISAR / NAMESPACE ---
subprojects {
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
        if (android.namespace == null) {
            android.namespace = "com.example.pdbl_wudi_mobile_apps.${project.name.replace("-", "_")}"
        }
    }
}