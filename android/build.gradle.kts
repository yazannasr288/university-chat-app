allprojects {
    repositories {
        mavenCentral()
        google()
    }

    configurations.configureEach {
        exclude(group = "androidx.multidex", module = "multidex")

        resolutionStrategy.eachDependency {
            if (requested.group == "com.google.android.exoplayer") {
                useVersion("2.19.1")
                because("Force all subprojects/plugins to use newer ExoPlayer")
            }

            if (requested.group == "androidx.heifwriter") {
                useVersion("1.1.0")
                because("Force newer AndroidX HeifWriter")
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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