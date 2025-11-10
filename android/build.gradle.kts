allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // --- AJOUTEZ CETTE LOGIQUE ICI ---
    // On configure les modules Android (app ou library) dès que
    // le plugin est appliqué. 'withId' gère le cycle de vie pour nous.
    project.plugins.withId("com.android.application") {
        project.extensions.getByType<com.android.build.api.dsl.CommonExtension<*, *, *, *, *, *>>().apply {
            compileSdk = 34
        }
    }
    project.plugins.withId("com.android.library") {
        project.extensions.getByType<com.android.build.api.dsl.CommonExtension<*, *, *, *, *, *>>().apply {
            compileSdk = 34
        }
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


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}