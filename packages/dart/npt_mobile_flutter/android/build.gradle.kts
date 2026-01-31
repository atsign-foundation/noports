allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Gradle configuration to handle namespace issues in dependencies
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Set default namespace if not specified (for older plugins)
            if (androidExtension.namespace == null) {
                val projectName = project.name.replace("_", ".")
                androidExtension.namespace = "com.atsign.$projectName"
            }
            
            // Force all subprojects to use Java 17
            androidExtension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExtension.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
        
        // Configure Kotlin tasks to use JVM target 17
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
