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

    // --- CORRECTION FINALE ---
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            
            // On doit fournir les 6 arguments génériques (ici, des wildcards *)
            // pour que Kotlin puisse résoudre le type 'CommonExtension'.
            project.extensions.findByType<com.android.build.api.dsl.CommonExtension<*, *, *, *, *, *>>()?.apply {
                
                // 'compileSdk' sera maintenant résolu correctement.
                compileSdk = 34
            }
        }
    }
    // --- FIN DE LA CORRECTION ---
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}