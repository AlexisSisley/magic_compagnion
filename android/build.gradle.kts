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

    // --- CORRECTION ---
    // Cette logique est exécutée après l'évaluation des projets.
    afterEvaluate {
        // Cible uniquement les sous-projets qui sont des modules Android
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            
            // Nous utilisons le nom complet de la classe 'CommonExtension'
            // pour éviter les problèmes d'import sur le script racine.
            // 'CommonExtension' est l'interface partagée pour 'application' et 'library'.
            project.extensions.findByType<com.android.build.api.dsl.CommonExtension>()?.apply {
                
                // Force le compileSdk pour ce module
                compileSdk = 34
            }
        }
    }
    // --- FIN DE LA CORRECTION ---
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}